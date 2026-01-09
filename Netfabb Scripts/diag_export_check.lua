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

if not tray then
    log("Error: No tray found. Aborting.")
    return
end

-- Helper to safely check property and call method
local function try_method(obj, method_name, arg1)
    log("Checking " .. method_name .. "...")
    local func = nil
    -- Safe property access
    local ok_access, err_access = pcall(function()
        func = obj[method_name]
    end)

    if ok_access and type(func) == "function" then
        log("  Method exists. Executing...")
        local ok_call, err_call = pcall(function() func(obj, arg1) end)
        if ok_call then
            log("  SUCCESS: " .. method_name .. " executed.")
        else
            log("  FAILURE: " .. method_name .. " execution failed: " .. tostring(err_call))
        end
    else
        log("  Method does not exist or property access failed.")
        if not ok_access then log("  Access Error: " .. tostring(err_access)) end
    end
end

-- 2. Test Tray Export Methods
local path_a = save_path_base .. "test_tray_saveto3mf.3mf"
try_method(tray, "saveto3mf", path_a)

local path_b = save_path_base .. "test_tray_save.3mf"
try_method(tray, "save", path_b)

local path_c = save_path_base .. "test_tray_export.3mf"
try_method(tray, "export", path_c)


-- 3. Test Mesh Export Methods (Fallback)
log("\n[Test D] Checking mesh:saveto3mf (First Part)...")
if tray.root and tray.root.meshcount > 0 then
    local tm = tray.root:getmesh(0)
    local lm = tm.mesh

    if lm then
        local path_d = save_path_base .. "test_mesh_saveto3mf.3mf"
        try_method(lm, "saveto3mf", path_d)

        -- Also try exporting the TrayMesh (tm) directly?
        log("\n[Test E] Checking TrayMesh:saveto3mf...")
        local path_e = save_path_base .. "test_traymesh_saveto3mf.3mf"
        try_method(tm, "saveto3mf", path_e)
    else
        log("First part has no mesh property.")
    end
else
    log("No parts in tray to test mesh export.")
end

log("--- Diagnostic Export Test End ---")
