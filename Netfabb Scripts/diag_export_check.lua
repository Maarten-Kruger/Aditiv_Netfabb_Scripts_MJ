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

log("--- Diagnostic Export Test Start (Round 2) ---")

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

-- 2. Introspect TrayMesh for 'support' methods
if tray.root and tray.root.meshcount > 0 then
    local tm = tray.root:getmesh(0)
    log("\n[Introspecting TrayMesh: " .. tm.name .. "]")

    local mt = getmetatable(tm)
    if mt then
        for k, v in pairs(mt) do
             if string.find(k, "support") or string.find(k, "save") then
                 log("  Found method/prop: " .. k)
             end
        end
    else
        log("  No metatable accessible.")
    end

    -- 3. Test: Export Baked Support Mesh to 3MF
    -- This tests if we can at least get the support GEOMETRY out, even if not parametric.
    log("\n[Test F] Generating Baked Support Mesh and Exporting to 3MF...")
    -- createsupportedmesh(mergepart, mergeopensupport, mergeclosedsupport, openthickening)
    local baked_tm = nil
    if tm.createsupportedmesh then
        local ok, res = pcall(function() return tm:createsupportedmesh(true, true, true, 0.0) end)
        if ok and res then
            baked_tm = res
            log("  createsupportedmesh successful.")
        else
            log("  createsupportedmesh failed: " .. tostring(res))
        end
    end

    if baked_tm then
        -- Check what baked_tm is (TrayMesh or LuaMesh?)
        -- If it's a TrayMesh, access .mesh. If LuaMesh, use directly.
        local mesh_to_save = nil
        if baked_tm.mesh then
            mesh_to_save = baked_tm.mesh
            log("  Result is TrayMesh, using .mesh")
        else
            mesh_to_save = baked_tm
            log("  Result seems to be LuaMesh")
        end

        local path_f = save_path_base .. "test_baked_supports.3mf"
        try_method(mesh_to_save, "saveto3mf", path_f)
    end

    -- 4. Test: Export Separate Support Mesh
    log("\n[Test G] Generating Separate Support Mesh and Exporting...")
    local support_only_tm = nil
    if tm.createsupportedmesh then
         -- mergepart=false, mergesupports=true
         local ok, res = pcall(function() return tm:createsupportedmesh(false, true, true, 0.0) end)
         if ok and res then support_only_tm = res end
    end

    if support_only_tm then
        local mesh_to_save = support_only_tm.mesh or support_only_tm
        local path_g = save_path_base .. "test_support_only.3mf"
        try_method(mesh_to_save, "saveto3mf", path_g)
    end

    -- 5. Test: Save .support file? (If such method exists)
    log("\n[Test H] Checking savesupport method...")
    local path_h = save_path_base .. "test_support_file.support"
    try_method(tm, "savesupport", path_h)

end

-- 6. Check System Save Project (Last Resort for "Tray" save)
log("\n[Test I] Checking system:saveproject...")
if system.saveproject then
    -- saveproject(filename)
    local path_i = save_path_base .. "test_project.fabbproject"
    try_method(system, "saveproject", path_i)
end

log("--- Diagnostic Export Test End (Round 2) ---")
