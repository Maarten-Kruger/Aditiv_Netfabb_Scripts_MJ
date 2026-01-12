-- Diagnostic_3MF_Importer.lua
-- Diagnostic script to test 3MF import methods and support editability.

-- Standard Logging Setup
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Diagnostic_3MF_Importer ---")

-- 1. File Selection (Native Windows Dialog)
log("Opening file dialog...")
local file_path = system:showopendialog("*.3mf")

if not file_path or file_path == "" then
    log("No file selected. Exiting.")
    return
end

-- 2. Setup Logging to File
-- Log file will be: [SelectedFile]_diagnostic_log.txt
local log_file_path = file_path .. "_diagnostic_log.txt"

if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if ok then
        log("Log file successfully set to: " .. log_file_path)
    else
        log("Failed to set log file: " .. tostring(err))
    end
end

log("Selected file: " .. file_path)

-- Helper to inspect system keys
log("Inspecting 'system' keys for '3mf'...")
local ok_keys, err_keys = pcall(function()
    for k, v in pairs(system) do
        if string.find(string.lower(k), "3mf") then
            log("Found system key: " .. k .. " (" .. type(v) .. ")")
        end
    end
end)
if not ok_keys then
    log("Error iterating system keys: " .. tostring(err_keys))
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
log("--- Testing Method 1: system:load3mf ---")
local ok_m1, res_m1 = pcall(function() return system:load3mf(file_path) end)

if ok_m1 then
    log("Method 1 call returned success.")
    local mesh = res_m1

    -- system:load3mf might return true/nil instead of mesh, check tray
    if type(mesh) ~= 'userdata' then
        log("Method 1 result is " .. type(mesh) .. ". Checking tray root for last mesh.")
        if tray and tray.root and tray.root.meshcount > 0 then
             mesh = tray.root:getmesh(tray.root.meshcount - 1)
        else
             log("Tray is empty or unavailable.")
             mesh = nil
        end
    end

    if type(mesh) == 'userdata' then
        local old_name = "Unknown"
        pcall(function() old_name = mesh.name end)
        log("Mesh loaded. Name: " .. old_name)

        -- Rename
        pcall(function() mesh.name = old_name .. "_load3mf" end)

        -- Check support
        local has_s, info_s = check_support(mesh)
        log("Support check: " .. info_s)
    else
        log("Method 1 failed to identify a loaded mesh.")
    end
else
    log("Method 1 failed: " .. tostring(res_m1))
end


-- Method 2: system:create3mfimporter
log("--- Testing Method 2: system:create3mfimporter ---")

local importer = nil
local ok_create, res_create = pcall(function() return system:create3mfimporter() end)

if ok_create and res_create then
    log("system:create3mfimporter() exists and returned object.")
    importer = res_create

    -- Try to inspect metatable
    local mt = getmetatable(importer)
    if mt then
        log("Importer metatable keys:")
        for k,v in pairs(mt) do
            log("  " .. tostring(k))
        end
    else
        log("Importer has no accessible metatable.")
    end

    -- Attempt import using probable methods
    local import_success = false

    -- Try :import(path)
    log("Attempting importer:import(path)...")
    local ok_imp, res_imp = pcall(function() return importer:import(file_path) end)
    if ok_imp then
        log("importer:import call success.")
        import_success = true
    else
        log("importer:import failed or missing: " .. tostring(res_imp))

        -- Try :load(path)
        log("Attempting importer:load(path)...")
        local ok_load, res_load = pcall(function() return importer:load(file_path) end)
        if ok_load then
            log("importer:load call success.")
            import_success = true
        else
             log("importer:load failed or missing: " .. tostring(res_load))

             -- Try :execute(path)
             log("Attempting importer:execute(path)...")
             local ok_exec, res_exec = pcall(function() return importer:execute(file_path) end)
             if ok_exec then
                  log("importer:execute call success.")
                  import_success = true
             else
                  log("importer:execute failed: " .. tostring(res_exec))
             end
        end
    end

    if import_success then
         -- Rename last mesh
         if tray and tray.root and tray.root.meshcount > 0 then
             local mesh = tray.root:getmesh(tray.root.meshcount - 1)

             local current_name = "Unknown"
             pcall(function() current_name = mesh.name end)

             -- Distinguish from Method 1
             if not string.find(current_name, "_load3mf") then
                 pcall(function() mesh.name = current_name .. "_importer" end)
                 log("Renamed import result to: " .. current_name .. "_importer")

                 local has_s, info_s = check_support(mesh)
                 log("Support check: " .. info_s)
             else
                 log("Last mesh (name: " .. current_name .. ") seems to be from Method 1. Method 2 might not have added a new mesh.")
             end
         else
             log("Tray empty after successful import call?")
         end
    end

else
    log("system:create3mfimporter not available: " .. tostring(res_create))

    -- Fallback Probe: system:createcadimport for 3mf?
    log("Probing system:createcadimport for 3mf...")
    local ok_cad, importer_cad = pcall(function() return system:createcadimport(0) end)
    if ok_cad and importer_cad then
         local ok_cimp, res_cimp = pcall(function() return importer_cad:import(file_path) end)
         if ok_cimp then
              log("createcadimport successfully imported 3mf.")
               if tray and tray.root and tray.root.meshcount > 0 then
                   local mesh = tray.root:getmesh(tray.root.meshcount - 1)
                   local cname = mesh.name
                   if not string.find(cname, "_load3mf") and not string.find(cname, "_importer") then
                        mesh.name = cname .. "_cadimport"
                        log("Renamed to " .. mesh.name)
                   end
               end
         else
              log("createcadimport failed to import: " .. tostring(res_cimp))
         end
    else
         log("createcadimport failed: " .. tostring(importer_cad))
    end
end

-- Refresh view
pcall(function() application:triggerdesktopevent('updateparts') end)

log("--- End of Diagnostic ---")
pcall(function() system:messagebox("Diagnostic Complete. Log saved to:\n" .. log_file_path) end)
