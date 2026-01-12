-- Diagnostics_Probe.lua
-- Probes for properties on Tray, TrayMesh, and LuaMesh objects.
-- Uses metatable inspection and multiple strategies to find the active tray.

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
    if ok then return val else return nil end
end

-- Helper to inspect object metatable
function dump_meta(obj, obj_name)
    if not obj then return end
    log("--- Inspecting Metatable: " .. obj_name .. " ---")
    local mt = getmetatable(obj)
    if mt then
        -- Try to find __index
        local index = mt.__index
        if type(index) == "table" then
            log("Fields in __index table:")
            for k, v in pairs(index) do
                log("  " .. tostring(k) .. " (" .. type(v) .. ")")
            end
        else
            log("__index is " .. type(index))
        end

        for k, v in pairs(mt) do
             if k ~= "__index" then
                log("  [MT] " .. tostring(k) .. " (" .. type(v) .. ")")
             end
        end
    else
        log("No metatable found.")
    end
    log("-------------------------------------------")
end

log("--- Starting Comprehensive Probe ---")
log("Log Path: " .. log_path)

-- 1. Determine Active Tray
local tray = nil
local tray_source = "None"

-- Check global tray (Main Lua Automation)
if _G.tray then
    tray = _G.tray
    tray_source = "_G.tray"
end

-- Fallback: Check netfabbtrayhandler for ANY populated tray
if (not tray) and _G.netfabbtrayhandler then
    log("Checking netfabbtrayhandler for trays with meshes...")
    for i = 0, netfabbtrayhandler.traycount - 1 do
        local t = netfabbtrayhandler:gettray(i)
        if t and t.root and t.root.meshcount > 0 then
            tray = t
            tray_source = "netfabbtrayhandler:gettray(" .. i .. ")"
            break
        end
    end
    -- If no populated tray found, just grab the first one
    if not tray and netfabbtrayhandler.traycount > 0 then
         tray = netfabbtrayhandler:gettray(0)
         tray_source = "netfabbtrayhandler:gettray(0) (Empty)"
    end
end

if tray then
    log("Selected Tray Source: " .. tray_source)
    dump_meta(tray, "Tray")

    -- 2. Probe Tray Properties
    log("-- Tray Properties Check --")
    local tray_props = {
        "buildtime", "totalbuildtime", "estimatedbuildtime", "build_time", "time_estimate",
        "layerthickness", "sliceheight", "layer_thickness", "thickness", "z_step",
        "name", "parameters", "settings", "machine", "machineshape"
    }

    for _, p in ipairs(tray_props) do
        local val = safe_get(tray, p)
        if val ~= nil then
            log("  Tray." .. p .. ": " .. tostring(val) .. " (" .. type(val) .. ")")
        end
    end

    -- Check for build time methods
    local tray_methods = {"getbuildtime", "getestimatedbuildtime", "calctime"}
    for _, m in ipairs(tray_methods) do
        local val = nil
        local ok, err = pcall(function() val = tray[m](tray) end)
        if ok and val ~= nil then
             log("  Tray:" .. m .. "(): " .. tostring(val))
        end
    end

    -- 3. Probe Mesh Properties
    if tray.root and tray.root.meshcount > 0 then
        local tm = tray.root:getmesh(0)
        log("Got TrayMesh 0: " .. safe_get(tm, "name"))

        dump_meta(tm, "TrayMesh")

        log("-- TrayMesh Properties Check --")
        local tm_props = {"supportvolume", "volume", "partvolume", "meshvolume", "selected", "outbox"}
        for _, p in ipairs(tm_props) do
            local val = safe_get(tm, p)
            if val ~= nil then
                 if p == "outbox" then
                    log("  TrayMesh.outbox: Found")
                 else
                    log("  TrayMesh." .. p .. ": " .. tostring(val))
                 end
            end
        end

         -- TrayMesh methods
        local tm_methods = {"getsupportvolume", "calcsupportvolume", "calcvolume", "getvolume", "calcoutbox"}
        for _, m in ipairs(tm_methods) do
             local val = nil
             local ok, err = pcall(function() val = tm[m](tm) end)
             if ok and val ~= nil then
                 log("  TrayMesh:" .. m .. "(): " .. tostring(val))
             end
        end

        -- TrayMesh Outbox Calc
        local tm_ob = safe_get(tm, "outbox")
        if tm_ob then
             local w = tm_ob.maxx - tm_ob.minx
             local d = tm_ob.maxy - tm_ob.miny
             local h = tm_ob.maxz - tm_ob.minz
             local vol = w * d * h
             log("  TrayMesh.outbox Volume: " .. vol)
        end

        -- 4. Probe Underlying LuaMesh
        local mesh = safe_get(tm, "mesh")
        if mesh then
            log("Got LuaMesh")
            dump_meta(mesh, "LuaMesh")

            log("-- LuaMesh Properties Check --")
            local m_props = {"volume", "surface", "area", "outbox"}
            for _, p in ipairs(m_props) do
                local val = safe_get(mesh, p)
                if val ~= nil then
                    log("  LuaMesh." .. p .. ": " .. tostring(val))
                end
            end

            local m_methods = {"calcvolume", "calcsurface"}
            for _, m in ipairs(m_methods) do
                local val = nil
                local ok, err = pcall(function() val = mesh[m](mesh) end)
                if ok and val ~= nil then
                    log("  LuaMesh:" .. m .. "(): " .. tostring(val))
                end
            end

            -- LuaMesh Outbox
            local m_ob = safe_get(mesh, "outbox")
             if m_ob then
                 local w = m_ob.maxx - m_ob.minx
                 local d = m_ob.maxy - m_ob.miny
                 local h = m_ob.maxz - m_ob.minz
                 local vol = w * d * h
                 log("  LuaMesh.outbox Volume: " .. vol)
            end
        end

        -- 5. Check for Support Object Properties
        log("-- Support Specific Check --")
        local s_props = {"support", "supports", "supportmesh"}
        for _, p in ipairs(s_props) do
            local val = safe_get(tm, p)
            if val ~= nil then
                log("  TrayMesh." .. p .. ": Found (" .. type(val) .. ")")
            end
        end

    else
        log("No meshes in tray.")
    end

else
    log("No accessible tray found via _G.tray or netfabbtrayhandler.")
end

log("--- End Probe ---")
