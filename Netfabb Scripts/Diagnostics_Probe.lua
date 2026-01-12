-- Diagnostics_Probe.lua
-- Probes for properties on Tray, TrayMesh, and LuaMesh objects.
-- Deep dive into Support objects and Tray Parameters.
-- V4 Logic + Summary Table.

-- 1. Prompt for Directory Path
local path_variable = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Path to Save Log File:", "Import Log Folder Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    path_variable = "C:\\"
end

path_variable = string.gsub(path_variable, '"', '')
if string.sub(path_variable, -1) ~= "\\" then
    path_variable = path_variable .. "\\"
end

-- Standard Logging Setup
local log_file_name = "probe_log.txt"
local log_path = path_variable .. log_file_name

if system and system.logtofile then
    pcall(function() system:logtofile(log_path) end)
end

function log(msg)
    if system and system.log then system:log(msg) end
    print(msg)
end

function safe_get(obj, key)
    local val = nil
    local ok, err = pcall(function() val = obj[key] end)
    if ok then return val, "OK" else return nil, err end
end

function safe_call(obj, method)
    -- Wrap the method lookup in pcall because obj[method_name] can throw errors on Netfabb objects
    local method_func = nil
    local ok_get, err_get = pcall(function() method_func = obj[method] end)

    if not ok_get then
        return nil, "Error looking up method: " .. tostring(err_get)
    end

    if not method_func then
        return nil, "Method not found (nil)"
    end

    if type(method_func) ~= "function" then
        return nil, "Property exists but is not a function (" .. type(method_func) .. ")"
    end

    local val = nil
    local ok_call, err_call = pcall(function() val = method_func(obj) end)
    if ok_call then return val, "OK" else return nil, err_call end
end

-- Helper to inspect object metatable
function dump_meta(obj, obj_name)
    if not obj then return end
    log("--- Inspecting Metatable: " .. obj_name .. " ---")
    local mt = getmetatable(obj)
    if mt then
        local index = mt.__index
        if type(index) == "table" then
            log("Fields in __index table:")
            for k, v in pairs(index) do
                log("  " .. tostring(k) .. " (" .. type(v) .. ")")
            end
        else
            log("__index is " .. type(index))
        end
        -- Dump actual keys if accessible
        for k,v in pairs(mt) do
            if k ~= "__index" then
                 log("  [MT] " .. tostring(k) .. " (" .. type(v) .. ")")
            end
        end
    else
        log("No metatable found.")
    end
    log("-------------------------------------------")
end

log("--- Starting Deep Probe v4 (Reverted & Enhanced) ---")
log("Log Path: " .. log_path)

-- Data Collection for Summary
local summary = {
    tray_buildtime = "nil",
    tray_layerthick = "nil",
    mesh_bb_vol = "nil",
    mesh_part_vol = "nil",
    mesh_sup_vol = "nil"
}

-- 1. Determine Active Tray
local tray = nil
if _G.tray then
    tray = _G.tray
    log("Using _G.tray")
elseif _G.netfabbtrayhandler then
    for i = 0, netfabbtrayhandler.traycount - 1 do
        local t = netfabbtrayhandler:gettray(i)
        if t and t.root and t.root.meshcount > 0 then
            tray = t
            log("Using netfabbtrayhandler tray " .. i)
            break
        end
    end
    if not tray and netfabbtrayhandler.traycount > 0 then
        tray = netfabbtrayhandler:gettray(0)
        log("Using netfabbtrayhandler tray 0 (Empty)")
    end
end

if tray then
    -------------------------------------------------------------------------
    -- TRAY PROBE
    -------------------------------------------------------------------------
    log("\n=== TRAY DATA PROBE ===")

    -- Try Slice
    local slice = nil
    local s_val, s_stat = safe_get(tray, "slice")
    if s_val then
        log("Tray has .slice property (" .. type(s_val) .. ")")
        slice = s_val
    else
        local s2_val, s2_stat = safe_call(tray, "getslice")
        if s2_val then
             log("Tray:getslice() returned (" .. type(s2_val) .. ")")
             slice = s2_val
        else
             log("Tray:getslice() failed: " .. tostring(s2_stat))
        end
    end

    if slice then
        dump_meta(slice, "SliceObject")
        local slice_props = {"buildtime", "layerthickness", "layersize", "zstep", "layercount"}
        for _, key in ipairs(slice_props) do
            local val, status = safe_get(slice, key)
             log("Slice." .. key .. ": " .. tostring(val) .. " (" .. status .. ")")

             -- Capture for summary
             if key == "buildtime" and val then summary.tray_buildtime = tostring(val) end
             if (key == "layerthickness" or key == "layersize") and val then summary.tray_layerthick = tostring(val) end
        end
    end

    -------------------------------------------------------------------------
    -- SYSTEM PROBE
    -------------------------------------------------------------------------
    log("\n=== SYSTEM / GLOBAL PROBE ===")
    if system then
        dump_meta(system, "System")
        local sys_props = {"machine", "buildroom", "layerthickness", "buildtime"}
        for _, key in ipairs(sys_props) do
             local val, status = safe_get(system, key)
             if val then log("system." .. key .. ": " .. tostring(val)) end
        end
    end

    -------------------------------------------------------------------------
    -- MESH PROBE
    -------------------------------------------------------------------------
    log("\n=== MESH DATA PROBE ===")

    if tray.root and tray.root.meshcount > 0 then
        local target_mesh = tray.root:getmesh(0)
        -- Find one with supports
        for i = 0, tray.root.meshcount - 1 do
            local m = tray.root:getmesh(i)
            if m.support then
                target_mesh = m
                log("Found mesh with supports at index " .. i)
                break
            end
        end

        log("Target Mesh: " .. target_mesh.name)

        -- 1. Volumes
        local vol, v_stat = safe_get(target_mesh, "volume")
        log("TrayMesh.volume: " .. tostring(vol))
        if vol then summary.mesh_part_vol = tostring(vol) end

        -- 2. Outbox
        local ob, ob_stat = safe_get(target_mesh, "outbox")
        if ob then
            local w = ob.maxx - ob.minx
            local d = ob.maxy - ob.miny
            local h = ob.maxz - ob.minz
            local v = w * d * h
            log(string.format("TrayMesh.outbox Volume: %f", v))
            summary.mesh_bb_vol = tostring(v)
        else
            log("TrayMesh.outbox: Nil")
        end

        -- 3. Support Volume
        local sup, sup_stat = safe_get(target_mesh, "support")
        if sup then
            local s_vol, s_v_stat = safe_get(sup, "volume")
            log("Support.volume: " .. tostring(s_vol) .. " (" .. s_v_stat .. ")")
            if s_vol then summary.mesh_sup_vol = tostring(s_vol) end
        else
            log("TrayMesh.support: Nil")
        end

    else
        log("No meshes in tray.")
    end

else
    log("No active tray found.")
end

log("\n===========================================")
log("===           SUMMARY REPORT            ===")
log("===========================================")
log(string.format("%-25s | %s", "DATA POINT", "VALUE"))
log("--------------------------|----------------")
log(string.format("%-25s | %s", "Tray Build Time", summary.tray_buildtime))
log(string.format("%-25s | %s", "Tray Layer Thickness", summary.tray_layerthick))
log(string.format("%-25s | %s", "Mesh Bounding Box Vol", summary.mesh_bb_vol))
log(string.format("%-25s | %s", "Mesh Part Volume", summary.mesh_part_vol))
log(string.format("%-25s | %s", "Mesh Support Volume", summary.mesh_sup_vol))
log("===========================================")

log("--- End Deep Probe v4 ---")
