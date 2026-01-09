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

log("--- Diagnostic Export Test Start ---")

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

-- 2. Test Tray Export Methods

-- Test A: tray:saveto3mf
log("\n[Test A] Checking tray:saveto3mf...")
local path_a = save_path_base .. "test_tray_saveto3mf.3mf"
if tray.saveto3mf then
    local ok, err = pcall(function() tray:saveto3mf(path_a) end)
    if ok then
        log("SUCCESS: tray:saveto3mf executed. Check " .. path_a)
    else
        log("FAILURE: tray:saveto3mf failed: " .. tostring(err))
    end
else
    log("Method tray:saveto3mf does not exist.")
end

-- Test B: tray:save
log("\n[Test B] Checking tray:save...")
local path_b = save_path_base .. "test_tray_save.3mf"
if tray.save then
    -- Assumption: 'save' might take a filepath
    local ok, err = pcall(function() tray:save(path_b) end)
    if ok then
        log("SUCCESS: tray:save executed. Check " .. path_b)
    else
        log("FAILURE: tray:save failed: " .. tostring(err))
    end
else
    log("Method tray:save does not exist.")
end

-- Test C: tray:export
log("\n[Test C] Checking tray:export...")
local path_c = save_path_base .. "test_tray_export.3mf"
if tray.export then
    local ok, err = pcall(function() tray:export(path_c) end)
    if ok then
        log("SUCCESS: tray:export executed. Check " .. path_c)
    else
        log("FAILURE: tray:export failed: " .. tostring(err))
    end
else
    log("Method tray:export does not exist.")
end


-- 3. Test Mesh Export Methods (Fallback)
log("\n[Test D] Checking mesh:saveto3mf (First Part)...")
if tray.root and tray.root.meshcount > 0 then
    local tm = tray.root:getmesh(0)
    local lm = tm.mesh

    if lm then
        local path_d = save_path_base .. "test_mesh_saveto3mf.3mf"
        if lm.saveto3mf then
            local ok, err = pcall(function() lm:saveto3mf(path_d) end)
            if ok then
                log("SUCCESS: mesh:saveto3mf executed. Check " .. path_d)
            else
                log("FAILURE: mesh:saveto3mf failed: " .. tostring(err))
            end
        else
            log("Method mesh:saveto3mf does not exist.")
        end
    else
        log("First part has no mesh property.")
    end
else
    log("No parts in tray to test mesh export.")
end

log("--- Diagnostic Export Test End ---")
