-- Diagnostic_3MF_Importer.lua
-- Diagnostic script to test 3MF import methods and support editability.
-- Updates: Added loadfabbproject and executemenucommand tests.

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Diagnostic_3MF_Importer (Project Mode) ---")

-- 1. File Selection
log("Opening file dialog...")
local file_path = system:showopendialog("*.3mf")

if not file_path or file_path == "" then
    log("No file selected. Exiting.")
    return
end

-- 2. Setup Logging
local log_file_path = file_path .. "_diagnostic_log.txt"
if system and system.logtofile then
    pcall(function() system:logtofile(log_file_path) end)
end
log("Selected file: " .. file_path)

-- Helper: Inspect object
local function inspect_object(obj, name)
    log("Inspecting " .. name .. " (" .. type(obj) .. "):")
    if type(obj) == 'table' then
        for k, v in pairs(obj) do
            if k ~= "mt" then
                log("  [" .. tostring(k) .. "] = " .. tostring(v) .. " (" .. type(v) .. ")")
            end
        end
        if obj.mt then
            log("  Wrapper .mt keys:")
            for k,v in pairs(obj.mt) do log("    " .. tostring(k)) end
        end
    elseif type(obj) == 'userdata' then
        local mt = getmetatable(obj)
        if mt then
            log("  Metatable keys:")
            for k,v in pairs(mt) do log("    " .. tostring(k)) end
        else
            log("  No accessible metatable.")
        end
    end
end


-- TEST 1: system:load3mf (Baseline)
log("--- Test 1: system:load3mf (Baseline) ---")
local ok1, res1 = pcall(function() return system:load3mf(file_path) end)
if ok1 then
    log("load3mf success. Result type: " .. type(res1))
    -- (We skip detailed processing here to focus on the new methods, unless it worked perfectly)
else
    log("load3mf failed: " .. tostring(res1))
end


-- TEST 2: system:loadfabbproject
log("--- Test 2: system:loadfabbproject ---")
log("Attempting to load .3mf as a project...")

local ok_proj, proj_obj = pcall(function() return system:loadfabbproject(file_path) end)

if ok_proj then
    log("loadfabbproject call returned success.")
    if proj_obj then
        log("Returned object type: " .. type(proj_obj))
        inspect_object(proj_obj, "ProjectObject")

        -- Try to access trays in the new project?
        -- The snippet said "You may need to 'activate' it or iterate through its trays."

        -- Check for typical project properties
        local ok_tc, tc = pcall(function() return proj_obj.traycount end)
        if ok_tc then
            log("Project has " .. tostring(tc) .. " trays.")
        else
            log("Could not read .traycount from project object.")
        end
    else
        log("Returned object is nil.")
    end
else
    log("loadfabbproject failed: " .. tostring(proj_obj))
end


-- TEST 3: system:executemenucommand(2138)
log("--- Test 3: system:executemenucommand(2138) ---")
log("Triggering 'Add Part' dialog command...")

local ok_cmd, res_cmd = pcall(function() return system:executemenucommand(2138) end)
if ok_cmd then
    log("Command 2138 executed successfully.")
else
    log("Command 2138 failed: " .. tostring(res_cmd))
end

log("--- Diagnostic Complete ---")
pcall(function() system:messagebox("Check Log: " .. log_file_path) end)
