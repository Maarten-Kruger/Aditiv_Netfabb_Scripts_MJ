-- Diagnostics_Probe.lua
-- Probes for properties on Tray, TrayMesh, and LuaMesh objects.
-- Deep dive into Support objects and Tray Parameters.
-- Fixed invalid property access errors.

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

function safe_call(obj, method_name)
    if not obj[method_name] then return nil, "Method not found" end
    local val = nil
    local ok, err = pcall(function() val = obj[method_name](obj) end)
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

log("--- Starting Deep Probe v3 ---")
log("Log Path: " .. log_path)

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
    -- TRAY PROBE (New Strategies)
    -------------------------------------------------------------------------
    log("\n=== TRAY DATA PROBE ===")

    -- Strategy 1: Project Level (fabbproject)
    if _G.fabbproject then
        log("fabbproject available.")
        -- Does project have build time?
        local proj_props = {"buildtime", "totalbuildtime"}
        for _, key in ipairs(proj_props) do
            local val, status = safe_get(fabbproject, key)
            if val then log("fabbproject." .. key .. ": " .. tostring(val)) end
        end
    else
        log("fabbproject NOT available.")
    end

    -- Strategy 2: Slice Information
    -- Build time often comes from slice data.
    local slice = nil
    local s_val, s_stat = safe_get(tray, "slice")
    if s_val then
        log("Tray has .slice property (" .. type(s_val) .. ")")
        slice = s_val
    else
        -- Try getslice()
        local s2_val, s2_stat = safe_call(tray, "getslice")
        if s2_val then
             log("Tray:getslice() returned (" .. type(s2_val) .. ")")
             slice = s2_val
        end
    end

    if slice then
        dump_meta(slice, "SliceObject")
        local slice_props = {"buildtime", "layerthickness", "zstep", "layercount"}
        for _, key in ipairs(slice_props) do
            local val, status = safe_get(slice, key)
             log("Slice." .. key .. ": " .. tostring(val) .. " (" .. status .. ")")
        end
    else
        log("No slice object found on tray.")
    end

    -- Strategy 3: Machine / Build Room Parameters
    -- Sometimes it's in tray.machine_type or similar
    local m_props = {"machine", "machinetype", "machine_type"}
    for _, key in ipairs(m_props) do
         local val, status = safe_get(tray, key)
         if val then log("Tray." .. key .. ": " .. tostring(val)) end
    end

    -- Strategy 4: Generic "info" or "GetParam" methods?
    -- Often in Lua bindings there is a generic parameter getter
    local param_methods = {"getparam", "getparameter", "getsetting", "get_parameter"}
    for _, m in ipairs(param_methods) do
        if tray[m] then
             log("Tray has method: " .. m)
             -- Try calling with common keys? (Dangerous without knowing signature)
        end
    end


    -------------------------------------------------------------------------
    -- MESH PROBE (Verified working: volume, outbox, support.volume)
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

        -- 2. Outbox
        local ob, ob_stat = safe_get(target_mesh, "outbox")
        if ob then
            local w = ob.maxx - ob.minx
            local d = ob.maxy - ob.miny
            local h = ob.maxz - ob.minz
            local v = w * d * h
            log(string.format("TrayMesh.outbox Volume: %f", v))
        else
            log("TrayMesh.outbox: Nil")
        end

        -- 3. Support Volume
        local sup, sup_stat = safe_get(target_mesh, "support")
        if sup then
            -- We know .volume works now
            local s_vol, s_v_stat = safe_get(sup, "volume")
            log("Support.volume: " .. tostring(s_vol) .. " (" .. s_v_stat .. ")")

            -- Don't probe .vol or others that caused errors
        else
            log("TrayMesh.support: Nil")
        end

    else
        log("No meshes in tray.")
    end

else
    log("No active tray found.")
end

log("--- End Deep Probe v3 ---")
