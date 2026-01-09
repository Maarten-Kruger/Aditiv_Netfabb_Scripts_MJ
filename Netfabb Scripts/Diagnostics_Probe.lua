-- Diagnostics_Probe.lua
-- Probes for properties on Tray, TrayMesh, and LuaMesh objects.
-- Uses metatable inspection to discover available methods.

-- 1. Prompt for Directory Path
-- This popup asks the user for a filepath (or directory path).
local path_variable = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Path to Save Log File:", "Import Log Folder Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    -- Fallback to C:\ if cancelled, or we can just print to console only.
    -- But let's try to be helpful.
    path_variable = "C:\\"
end

-- Correctly Format the Path
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
    if system and system.log then
        system:log(msg)
    end
    print(msg)
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

        -- Iterate metatable directly just in case
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

if _G.netfabbtrayhandler then
    if netfabbtrayhandler.traycount > 0 then
        local tray = netfabbtrayhandler:gettray(0)
        log("Got Tray 0")

        dump_meta(tray, "Tray")

        -- 1. Probe Tray Properties
        log("-- Tray Properties Check --")
        local tray_props = {
            "buildtime", "totalbuildtime", "estimatedbuildtime", "build_time", "time_estimate",
            "layerthickness", "sliceheight", "layer_thickness", "thickness", "z_step",
            "name"
        }

        for _, p in ipairs(tray_props) do
            local val = nil
            local ok, err = pcall(function() val = tray[p] end)
            if ok and val ~= nil then
                log("  Tray." .. p .. ": " .. tostring(val))
            end
        end

        -- 2. Probe Mesh Properties
        if tray.root and tray.root.meshcount > 0 then
            local tm = tray.root:getmesh(0)
            log("Got TrayMesh 0: " .. tm.name)

            dump_meta(tm, "TrayMesh")

            log("-- TrayMesh Properties Check --")
            local tm_props = {"supportvolume", "volume", "partvolume", "meshvolume", "selected"}
            for _, p in ipairs(tm_props) do
                local val = nil
                local ok, err = pcall(function() val = tm[p] end)
                if ok and val ~= nil then
                    log("  TrayMesh." .. p .. ": " .. tostring(val))
                end
            end

             -- TrayMesh methods
            local tm_methods = {"getsupportvolume", "calcsupportvolume", "calcvolume", "getvolume"}
            for _, m in ipairs(tm_methods) do
                 local val = nil
                 local ok, err = pcall(function() val = tm[m](tm) end)
                 if ok and val ~= nil then
                     log("  TrayMesh:" .. m .. "(): " .. tostring(val))
                 end
            end

            -- TrayMesh Outbox
            local tm_ob = nil
            local ok_ob, err_ob = pcall(function() tm_ob = tm.outbox end)
            if ok_ob and tm_ob then
                 local w = tm_ob.maxx - tm_ob.minx
                 local d = tm_ob.maxy - tm_ob.miny
                 local h = tm_ob.maxz - tm_ob.minz
                 local vol = w * d * h
                 log("  TrayMesh.outbox: Found. Dimensions: " .. w .. " x " .. d .. " x " .. h)
                 log("  TrayMesh BoundingBox Volume: " .. vol)
            else
                 log("  TrayMesh.outbox: Not found.")
            end

            -- 3. Probe Underlying LuaMesh
            if tm.mesh then
                local mesh = tm.mesh
                log("Got LuaMesh")
                dump_meta(mesh, "LuaMesh")

                log("-- LuaMesh Properties Check --")
                local m_props = {"volume", "surface", "area"}
                for _, p in ipairs(m_props) do
                    local val = nil
                    local ok, err = pcall(function() val = mesh[p] end)
                    if ok and val ~= nil then
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
                local m_ob = nil
                local ok_mob, err_mob = pcall(function() m_ob = mesh.outbox end)
                 if ok_mob and m_ob then
                     local w = m_ob.maxx - m_ob.minx
                     local d = m_ob.maxy - m_ob.miny
                     local h = m_ob.maxz - m_ob.minz
                     local vol = w * d * h
                     log("  LuaMesh.outbox: Found. Dimensions: " .. w .. " x " .. d .. " x " .. h)
                     log("  LuaMesh BoundingBox Volume: " .. vol)
                else
                     log("  LuaMesh.outbox: Not found.")
                end
            end

            -- 4. Check for Support Object Properties
            -- Sometimes supports are separate properties
            log("-- Support Specific Check --")
            local s_props = {"support", "supports", "supportmesh"}
            for _, p in ipairs(s_props) do
                local val = nil
                local ok, err = pcall(function() val = tm[p] end)
                if ok and val ~= nil then
                    log("  TrayMesh." .. p .. ": Found (" .. type(val) .. ")")
                end
            end

        else
            log("No meshes in tray 0")
        end

    else
        log("No trays found.")
    end
else
    log("netfabbtrayhandler not available")
end

log("--- End Probe ---")
