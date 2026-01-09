-- diag_export_check.lua
-- Diagnostic script to test export methods and check for support preservation.
-- Output log: C:\Users\Maarten\OneDrive\Desktop\diag_log.txt
-- Output files: C:\Users\Maarten\OneDrive\Desktop\test_*.3mf

local log_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\diag_log.txt"
local save_path_base = "C:\\Users\\Maarten\\OneDrive\\Desktop\\"

-- Setup Logging using system:logtofile
if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_path) end)
    if not ok then
        if system.log then system:log("Failed to set log file: " .. tostring(err)) end
    end
end

local function log(msg)
    if system and system.log then
        system:log(msg)
    else
        print(msg)
    end
end

log("--- Diagnostic Export Test Start (Safe Mode) ---")

-- 1. Get Tray
local tray = nil
if _G.netfabbtrayhandler and netfabbtrayhandler.traycount > 0 then
    tray = netfabbtrayhandler:gettray(0)
    log("Got tray from netfabbtrayhandler.")
elseif _G.tray then
    tray = _G.tray
    log("Got tray from global variable 'tray'.")
end

-- Helper to safely check property and call method
local function try_method(obj, method_name, arg1, arg2)
    log("Checking " .. method_name .. "...")
    local func = nil
    -- Safe property access
    local ok_access, err_access = pcall(function()
        func = obj[method_name]
    end)

    if ok_access and type(func) == "function" then
        log("  Method exists. Executing...")
        local ok_call, err_call = pcall(function()
            if arg2 then func(obj, arg1, arg2) else func(obj, arg1) end
        end)
        if ok_call then
            log("  SUCCESS: " .. method_name .. " executed.")
            return true
        else
            log("  FAILURE: " .. method_name .. " execution failed: " .. tostring(err_call))
            return false
        end
    else
        log("  Method does not exist or property access failed.")
        return false
    end
end

-- 2. Test Project Saving (Safely)
log("\n[Test I] Checking system:saveproject (Full Project)...")
-- Pcall the access itself
local has_saveproject = false
pcall(function()
    if system.saveproject then has_saveproject = true end
end)

if has_saveproject then
    local path_i = save_path_base .. "test_project.fabbproject"
    try_method(system, "saveproject", path_i)
else
    log("system:saveproject not found.")
end

-- 3. Test FabbProject global if available
log("\n[Test J] Checking fabbproject:savetofile...")
if _G.fabbproject then
    local path_j = save_path_base .. "test_fabbproject.fabbproject"
    try_method(fabbproject, "savetofile", path_j)
else
    log("fabbproject global is nil.")
end

-- 4. Test Saving .support file explicitly
if tray and tray.root and tray.root.meshcount > 0 then
    local tm = tray.root:getmesh(0)
    log("\n[Test K] Checking savesupport on TrayMesh...")
    local path_k = save_path_base .. "test_support.support"
    try_method(tm, "savesupport", path_k)
end

log("--- Diagnostic Export Test End (Safe Mode) ---")
