-- Diagnostics_Probe.lua
-- Probes for properties on Tray, TrayMesh, and LuaMesh objects.
-- Deep dive into Support objects and Tray Parameters.
-- ALSO PROBES FOR FILE I/O CAPABILITIES.

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
    local method_func = nil
    local ok_get, err_get = pcall(function() method_func = obj[method] end)

    if not ok_get or not method_func or type(method_func) ~= "function" then
        return nil, "Method invalid"
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

log("--- Starting Deep Probe v5 (IO Check) ---")
log("Log Path: " .. log_path)

-------------------------------------------------------------------------
-- GLOBAL LIBRARY CHECK
-------------------------------------------------------------------------
log("\n=== GLOBAL LIBRARY CHECK ===")
local libs = {"io", "os", "string", "table", "math", "package", "debug", "lfs"}
for _, l in ipairs(libs) do
    if _G[l] then
        log("Global '" .. l .. "' FOUND (" .. type(_G[l]) .. ")")
        if l == "io" then
            local open_exists = _G.io.open and "yes" or "no"
            log("  io.open exists: " .. open_exists)
        elseif l == "os" then
            local exec_exists = _G.os.execute and "yes" or "no"
            log("  os.execute exists: " .. exec_exists)
        end
    else
        log("Global '" .. l .. "' NOT FOUND (nil)")
    end
end

-------------------------------------------------------------------------
-- SYSTEM CAPABILITY CHECK
-------------------------------------------------------------------------
log("\n=== SYSTEM CAPABILITY CHECK ===")
if system then
    dump_meta(system, "System")

    -- Search for anything that looks like file saving
    log("-- Searching for 'save' or 'write' methods in system --")
    local mt = getmetatable(system)
    if mt and mt.__index and type(mt.__index) == "table" then
        for k,v in pairs(mt.__index) do
             if type(k) == "string" then
                 local ks = string.lower(k)
                 if string.find(ks, "save") or string.find(ks, "write") or string.find(ks, "file") then
                     log("  Found candidate: " .. k .. " (" .. type(v) .. ")")
                 end
             end
        end
    end
else
    log("System object not found!")
end

-------------------------------------------------------------------------
-- TRAY PROBE
-------------------------------------------------------------------------
log("\n=== TRAY DATA PROBE ===")

local tray = nil
if _G.tray then
    tray = _G.tray
elseif _G.netfabbtrayhandler and netfabbtrayhandler.traycount > 0 then
    tray = netfabbtrayhandler:gettray(0)
end

if tray then
    local slice = nil
    local s_val, s_stat = safe_get(tray, "slice")
    if s_val then slice = s_val end
    if not slice then
        local s2_val, s2_stat = safe_call(tray, "getslice")
        if s2_val then slice = s2_val end
    end

    if slice then
        dump_meta(slice, "SliceObject")
        local slice_props = {"buildtime", "layerthickness", "layersize", "zstep", "layercount"}
        for _, key in ipairs(slice_props) do
            local val, status = safe_get(slice, key)
             log("Slice." .. key .. ": " .. tostring(val) .. " (" .. status .. ")")
        end
    end
else
    log("No tray available for probe.")
end

log("--- End Deep Probe v5 ---")
