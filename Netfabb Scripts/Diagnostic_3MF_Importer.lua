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
            if k ~= "mt" then
                log("  [" .. tostring(k) .. "] = " .. tostring(v) .. " (" .. type(v) .. ")")
            end
            if type(v) == 'userdata' then
                local ok_name, m_name = pcall(function() return v.name end)
                if ok_name then log("    -> Mesh Name: " .. tostring(m_name)) end
            end
        end
        -- Inspect wrapper metatable
        if obj.mt then
            log("  Wrapper .mt keys:")
            for k,v in pairs(obj.mt) do
                log("    " .. tostring(k))
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

    inspect_object(res_m1, "load3mf_result")

    -- Rename if possible
    if type(res_m1) == 'table' then
        -- Iterate regular keys
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
        pcall(function()
             local old = res_m1.name
             res_m1.name = old .. "_load3mf"
             log("Renamed " .. old .. " to " .. res_m1.name)
             local _, s_info = check_support(res_m1)
             log("Support: " .. s_info)
        end)
    end
else
    log("Method 1 failed: " .. tostring(res_m1))
end


-- Method 2: system:create3mfimporter
log("--- Testing Method 2: system:create3mfimporter ---")
-- Error hint: create3mfimporter(string, boolean, string, object)
-- Trying to pass tray (or tray.root) as the object
local target_obj = nil
if tray then target_obj = tray end

local ok_create, res_create = pcall(function()
    return system:create3mfimporter(file_path, true, "", target_obj)
end)

if ok_create and res_create then
    log("system:create3mfimporter(path, true, '', tray) returned object.")
    local importer = res_create
    inspect_object(importer, "3mf_importer_obj")

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

    -- Try to deduce method from inspection in previous step, but for now just log the mt
else
    log("createcadimport failed: " .. tostring(importer_cad))
end

-- Finalize
pcall(function() application:triggerdesktopevent('updateparts') end)
log("--- End of Diagnostic ---")
pcall(function() system:messagebox("Diagnostic Complete.\nLog: " .. log_file_path) end)
