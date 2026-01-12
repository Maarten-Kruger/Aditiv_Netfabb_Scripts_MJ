-- Diagnostics_Probe.lua
-- Probes for properties on Tray, TrayMesh, and LuaMesh objects.
-- Deep dive into Support objects and Tray Parameters.

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

function safe_call(obj, method_name, ...)
    if not obj[method_name] then return nil, "Method not found" end
    local val = nil
    local ok, err = pcall(function() val = obj[method_name](obj, ...) end)
    if ok then return val, "OK" else return nil, err end
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
    else
        log("No metatable found.")
    end
    log("-------------------------------------------")
end

log("--- Starting Deep Probe ---")
log("Log Path: " .. log_path)

-- 1. Determine Active Tray
local tray = nil
if _G.tray then
    tray = _G.tray
    log("Using _G.tray")
elseif _G.netfabbtrayhandler then
    -- Find first populated tray
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

    -- List of candidates for Build Time and Layer Thickness
    local tray_candidates = {
        "buildtime", "totalbuildtime", "estimatedbuildtime", "timeestimate",
        "layerthickness", "thickness", "sliceheight", "layerheight",
        "zstep", "z_step", "layer_thickness"
    }

    for _, key in ipairs(tray_candidates) do
        local val, status = safe_get(tray, key)
        log(string.format("Property '%s': %s (Status: %s)", key, tostring(val), status))
    end

    -- Try accessing internal tables/settings
    local settings_containers = {"parameters", "settings", "machine", "config"}
    for _, key in ipairs(settings_containers) do
        local val, status = safe_get(tray, key)
        if val then
             log(string.format("Container '%s' found (%s). Probing...", key, type(val)))
             -- If it's a table/userdata, try to find our keys inside it
             if type(val) == "table" or type(val) == "userdata" then
                 for _, subkey in ipairs(tray_candidates) do
                     local subval = nil
                     pcall(function() subval = val[subkey] end)
                     if subval then
                         log(string.format("  -> Found '%s' inside '%s': %s", subkey, key, tostring(subval)))
                     end
                 end
             end
        else
             log(string.format("Container '%s': %s", key, tostring(val)))
        end
    end

    -------------------------------------------------------------------------
    -- MESH PROBE
    -------------------------------------------------------------------------
    log("\n=== MESH DATA PROBE ===")

    if tray.root and tray.root.meshcount > 0 then
        -- Find a mesh that has supports if possible, otherwise just the first one
        local target_mesh = tray.root:getmesh(0)

        -- Try to find one with "support" property not nil
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
        log("-- Volumes --")
        local vol_keys = {"volume", "partvolume", "meshvolume", "supportvolume"}
        for _, key in ipairs(vol_keys) do
            local val, status = safe_get(target_mesh, key)
            log(string.format("TrayMesh.%s: %s", key, tostring(val)))
        end

        -- 2. Outbox (Bounding Box)
        log("-- Bounding Box --")
        local ob, status = safe_get(target_mesh, "outbox")
        if ob then
            local w = ob.maxx - ob.minx
            local d = ob.maxy - ob.miny
            local h = ob.maxz - ob.minz
            local v = w * d * h
            log(string.format("TrayMesh.outbox: %f x %f x %f (Vol: %f)", w, d, h, v))
        else
            log("TrayMesh.outbox: Nil/Error")
        end

        -- 3. Support Object Deep Dive
        log("-- Support Object --")
        local sup, sup_status = safe_get(target_mesh, "support")
        if sup then
            log("TrayMesh.support is present (" .. type(sup) .. ")")
            dump_meta(sup, "SupportObject")

            -- Probe Support Object
            local sup_keys = {"volume", "vol", "getvolume", "trianglecount"}
            for _, key in ipairs(sup_keys) do
                 local val, s = safe_get(sup, key)
                 log(string.format("Support.%s: %s", key, tostring(val)))

                 -- Try as method too
                 local val_m, s_m = safe_call(sup, key)
                 if s_m == "OK" then
                     log(string.format("Support:%s(): %s", key, tostring(val_m)))
                 end
            end
        else
            log("TrayMesh.support is NIL.")
        end

    else
        log("No meshes in tray.")
    end

else
    log("No active tray found.")
end

log("--- End Deep Probe ---")
