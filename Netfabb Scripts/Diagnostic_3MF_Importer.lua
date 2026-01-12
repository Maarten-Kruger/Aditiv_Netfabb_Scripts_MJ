-- Diagnostic_3MF_Importer.lua
-- Diagnostic script to test 3MF import methods and support editability.

-- Standard Logging Setup
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- Attempt to resolve a dynamic path for logging
-- 1. File Selection & Log Setup (Template Style)
local file_path = ""
local ok_input, input_path = pcall(function()
    return system:inputdlg("Enter full path to the .3mf file:", "Input 3MF File Path", "C:\\")
end)

if ok_input and input_path and input_path ~= "" then
    file_path = input_path
else
    log("No path entered. Exiting.")
    return
end

-- Sanitize path (remove quotes)
file_path = string.gsub(file_path, '"', '')

-- Check validity
if file_path == "" then
    log("Invalid path (empty after cleanup).")
    return
end

-- Setup Log File in the same directory (or parent if file)
local log_file_path = file_path .. "_diagnostic_log.txt"

local function log_to_file(msg)
    if system and system.logtofile then
        pcall(function() system:logtofile(log_file_path, msg) end)
    end
end

local function print_log(msg)
    log(msg)
    log_to_file(msg)
end

print_log("--- Starting Diagnostic_3MF_Importer ---")
print_log("Selected file: " .. file_path)
print_log("Log file set to: " .. log_file_path)

-- Helper to inspect system keys
print_log("Inspecting 'system' keys for '3mf'...")
local ok_keys, err_keys = pcall(function()
    for k, v in pairs(system) do
        if string.find(string.lower(k), "3mf") then
            print_log("Found system key: " .. k .. " (" .. type(v) .. ")")
        end
    end
end)
if not ok_keys then
    print_log("Error iterating system keys: " .. tostring(err_keys))
end


-- Helper: Check for supports on a mesh
local function check_support(mesh)
    local has_support = false
    local support_info = "None"

    local ok_supp, res_supp = pcall(function() return mesh.support end)
    if ok_supp and res_supp then
        has_support = true
        support_info = "Property .support exists"
        -- Try to get count if it's a table or object
        if type(res_supp) == 'table' or type(res_supp) == 'userdata' then
             -- Try generic counting if possible, or just report type
             support_info = support_info .. " (Type: " .. type(res_supp) .. ")"
        end
    else
        -- Try getsupportcount method
        local ok_count, count = pcall(function() return mesh:getsupportcount() end)
        if ok_count then
             has_support = true
             support_info = "Method :getsupportcount() returns " .. tostring(count)
        end
    end
    return has_support, support_info
end


-- Method 1: system:load3mf
print_log("--- Testing Method 1: system:load3mf ---")
local ok_m1, res_m1 = pcall(function() return system:load3mf(file_path) end)

if ok_m1 then
    print_log("Method 1 call returned success.")
    local mesh = res_m1
    -- system:load3mf returns the mesh object directly (based on memory),
    -- or we check the last added mesh if it returns nil/bool.

    if type(mesh) ~= 'userdata' then
        print_log("Method 1 returned " .. type(mesh) .. ", checking tray root for last mesh.")
        if tray and tray.root and tray.root.meshcount > 0 then
             mesh = tray.root:getmesh(tray.root.meshcount - 1)
        end
    end

    if type(mesh) == 'userdata' then
        local old_name = "Unknown"
        pcall(function() old_name = mesh.name end)
        print_log("Mesh loaded. Name: " .. old_name)

        -- Rename
        pcall(function() mesh.name = old_name .. "_load3mf" end)

        -- Check support
        local has_s, info_s = check_support(mesh)
        print_log("Support check: " .. info_s)
    else
        print_log("Method 1 failed to identify a loaded mesh.")
    end
else
    print_log("Method 1 failed: " .. tostring(res_m1))
end


-- Method 2: system:create3mfimporter
print_log("--- Testing Method 2: system:create3mfimporter ---")

local importer = nil
local ok_create, res_create = pcall(function() return system:create3mfimporter() end)

if ok_create and res_create then
    print_log("system:create3mfimporter() exists and returned object.")
    importer = res_create

    -- Try to inspect metatable
    local mt = getmetatable(importer)
    if mt then
        print_log("Importer metatable keys:")
        for k,v in pairs(mt) do
            print_log("  " .. tostring(k))
        end
    else
        print_log("Importer has no accessible metatable.")
    end

    -- Attempt import using probable methods
    local import_success = false

    -- Try :import(path)
    print_log("Attempting importer:import(path)...")
    local ok_imp, res_imp = pcall(function() return importer:import(file_path) end)
    if ok_imp then
        print_log("importer:import call success.")
        import_success = true
    else
        print_log("importer:import failed or missing: " .. tostring(res_imp))

        -- Try :load(path)
        print_log("Attempting importer:load(path)...")
        local ok_load, res_load = pcall(function() return importer:load(file_path) end)
        if ok_load then
            print_log("importer:load call success.")
            import_success = true
        else
             print_log("importer:load failed or missing: " .. tostring(res_load))

             -- Try :execute(path) ?
             print_log("Attempting importer:execute(path)...")
             local ok_exec, res_exec = pcall(function() return importer:execute(file_path) end)
             if ok_exec then
                  print_log("importer:execute call success.")
                  import_success = true
             else
                  print_log("importer:execute failed: " .. tostring(res_exec))
             end
        end
    end

    if import_success then
         -- Rename last mesh
         if tray and tray.root and tray.root.meshcount > 0 then
             local mesh = tray.root:getmesh(tray.root.meshcount - 1)

             -- Ensure we don't rename the one from Method 1 if Method 2 didn't actually add anything new
             -- (Ideally we track meshcount, but let's just rename whatever is last)
             local current_name = "Unknown"
             pcall(function() current_name = mesh.name end)

             if not string.find(current_name, "_load3mf") then
                 pcall(function() mesh.name = current_name .. "_importer" end)
                 print_log("Renamed import result to: " .. current_name .. "_importer")

                 local has_s, info_s = check_support(mesh)
                 print_log("Support check: " .. info_s)
             else
                 print_log("Last mesh seems to be from Method 1 (name: " .. current_name .. "). Method 2 might not have added a mesh.")
             end
         else
             print_log("Tray empty after successful import call?")
         end
    end

else
    print_log("system:create3mfimporter not available: " .. tostring(res_create))

    -- Fallback Probe: system:createcadimport for 3mf?
    -- Sometimes createcadimport handles everything.
    print_log("Probing system:createcadimport for 3mf...")
    local ok_cad, importer_cad = pcall(function() return system:createcadimport(0) end) -- 0 is a guess, usually void
    if ok_cad and importer_cad then
         -- Usually requires file extensions setup, but let's try direct import if possible
         -- CadImporter usually uses :import(path)
         local ok_cimp, res_cimp = pcall(function() return importer_cad:import(file_path) end)
         if ok_cimp then
              print_log("createcadimport successfully imported 3mf.")
               if tray and tray.root and tray.root.meshcount > 0 then
                   local mesh = tray.root:getmesh(tray.root.meshcount - 1)
                   local cname = mesh.name
                   if not string.find(cname, "_load3mf") and not string.find(cname, "_importer") then
                        mesh.name = cname .. "_cadimport"
                        print_log("Renamed to " .. mesh.name)
                   end
               end
         else
              print_log("createcadimport failed to import: " .. tostring(res_cimp))
         end
    end
end

-- Refresh view
pcall(function() application:triggerdesktopevent('updateparts') end)

print_log("--- End of Diagnostic ---")
pcall(function() system:messagebox("Diagnostic Complete. Check log.") end)
