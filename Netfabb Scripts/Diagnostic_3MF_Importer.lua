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

-- Helper: Check for supports on a mesh
local function check_support(mesh)
    local has_support = false
    local support_info = "None"

    local ok_supp, res_supp = pcall(function() return mesh.support end)
    if ok_supp and res_supp then
        has_support = true
        support_info = "Property .support exists"
        if type(res_supp) == 'table' or type(res_supp) == 'userdata' then
             support_info = support_info .. " (Type: " .. type(res_supp) .. ")"
        end
    else
        local ok_count, count = pcall(function() return mesh:getsupportcount() end)
        if ok_count then
             has_support = true
             support_info = "Method :getsupportcount() returns " .. tostring(count)
        end
    end
    return has_support, support_info
end

-- Helper: Inspect a table or userdata
local function inspect_object(obj, name)
    log("Inspecting " .. name .. " (" .. type(obj) .. "):")
    if type(obj) == 'table' then
        for k, v in pairs(obj) do
            log("  [" .. tostring(k) .. "] = " .. tostring(v) .. " (" .. type(v) .. ")")
            if type(v) == 'userdata' then
                local ok_name, m_name = pcall(function() return v.name end)
                if ok_name then log("    -> Mesh Name: " .. tostring(m_name)) end
            end
        end
    elseif type(obj) == 'userdata' then
        local mt = getmetatable(obj)
        if mt then
            log("  Metatable keys:")
            for k,v in pairs(mt) do
                log("    " .. tostring(k))
            end
        else
            log("  No accessible metatable.")
        end
    else
        log("  Not a table or userdata.")
    end
end


-- Method 1: system:load3mf
log("--- Testing Method 1: system:load3mf ---")
local ok_m1, res_m1 = pcall(function() return system:load3mf(file_path) end)

if ok_m1 then
    log("Method 1 call returned success. Result type: " .. type(res_m1))

    if type(res_m1) == 'table' then
        inspect_object(res_m1, "load3mf_result")
        -- If the table contains meshes, rename them
        for k, v in pairs(res_m1) do
             if type(v) == 'userdata' then
                  pcall(function()
                      local old = v.name
                      v.name = old .. "_load3mf"
                      log("Renamed " .. old .. " to " .. v.name)
                      local _, s_info = check_support(v)
                      log("Support: " .. s_info)
                  end)
             end
        end
    elseif type(res_m1) == 'userdata' then
        -- Single mesh returned
        pcall(function()
             local old = res_m1.name
             res_m1.name = old .. "_load3mf"
             log("Renamed " .. old .. " to " .. res_m1.name)
             local _, s_info = check_support(res_m1)
             log("Support: " .. s_info)
        end)
    else
        -- Check Global Tray
        log("Result was nil/bool. Checking global 'tray'...")
        if tray then
             log("Tray exists. Mesh count: " .. tostring(tray.root.meshcount))
             if tray.root.meshcount > 0 then
                  local mesh = tray.root:getmesh(tray.root.meshcount - 1)
                  log("Last mesh in tray: " .. mesh.name)
             end
        else
             log("Global 'tray' is nil.")
        end

        -- Check NetfabbTrayHandler
        log("Checking netfabbtrayhandler...")
        if netfabbtrayhandler then
             log("Tray count: " .. tostring(netfabbtrayhandler.traycount))
        end
    end
else
    log("Method 1 failed: " .. tostring(res_m1))
end


-- Method 2: system:create3mfimporter
log("--- Testing Method 2: system:create3mfimporter ---")
-- Error hint: create3mfimporter(string, boolean, string, object)
local ok_create, res_create = pcall(function()
    return system:create3mfimporter(file_path, true, "", nil)
end)

if ok_create and res_create then
    log("system:create3mfimporter(path, true, '', nil) returned object.")
    local importer = res_create
    inspect_object(importer, "3mf_importer_obj")

    -- Does it run automatically or need a method call?
    -- If it returns an object, we likely need to call something.
    log("Attempting :execute()...")
    local ok_exec, res_exec = pcall(function() return importer:execute() end)
    log("execute result: " .. tostring(ok_exec) .. " / " .. tostring(res_exec))

    if not ok_exec then
         log("Attempting :import()...")
         local ok_imp, res_imp = pcall(function() return importer:import() end)
         log("import result: " .. tostring(ok_imp) .. " / " .. tostring(res_imp))
    end

else
    log("create3mfimporter call failed: " .. tostring(res_create))
end


-- Method 3: system:createcadimport
log("--- Testing Method 3: system:createcadimport ---")

local ok_cad, importer_cad = pcall(function() return system:createcadimport(0) end)

if ok_cad and importer_cad then
    log("system:createcadimport(0) returned object.")
    inspect_object(importer_cad, "cad_importer_obj")

    -- Based on metatable inspection, we will know what to call.
    -- For now, blindly try 'addfile' and 'import' if not probed
    log("Attempting generic CAD methods...")

    local ok_add, res_add = pcall(function() return importer_cad:addfile(file_path) end)
    log("addfile result: " .. tostring(ok_add) .. " / " .. tostring(res_add))

    local ok_imp, res_imp = pcall(function() return importer_cad:import() end)
    log("import result: " .. tostring(ok_imp) .. " / " .. tostring(res_imp))

else
    log("createcadimport failed: " .. tostring(importer_cad))
end

-- Finalize
pcall(function() application:triggerdesktopevent('updateparts') end)
log("--- End of Diagnostic ---")
pcall(function() system:messagebox("Diagnostic Complete.\nLog: " .. log_file_path) end)
