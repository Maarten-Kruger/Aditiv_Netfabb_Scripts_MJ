-- diag_export_check.lua
-- Diagnostic script to find available export methods on Tray and System objects
-- Output is saved to C:\Users\Maarten\OneDrive\Desktop\diag_log.txt

local log_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\diag_log.txt"
local f = io.open(log_path, "w")
if not f then
    -- Try a fallback path if the specific one fails
    log_path = "C:\\diag_log.txt"
    f = io.open(log_path, "w")
end

local function log(msg)
    if f then
        f:write(msg .. "\n")
        f:flush()
    end
    if system and system.log then
        system:log(msg)
    end
end

log("--- Diagnostic Start ---")

-- 1. Inspect Global 'system'
log("\n[Checking System Methods]")
if system then
    local mt = getmetatable(system)
    if mt then
        for k, v in pairs(mt) do
            if type(v) == "function" or type(v) == "userdata" then
                if string.find(k, "save") or string.find(k, "export") or string.find(k, "write") then
                    log("system:" .. k)
                end
            end
        end
    else
        log("system has no metatable accessible.")
    end
end

-- 2. Inspect Tray Object
log("\n[Checking Tray Methods]")
local tray_to_check = nil

if _G.netfabbtrayhandler then
    if netfabbtrayhandler.traycount > 0 then
        tray_to_check = netfabbtrayhandler:gettray(0)
        log("Got tray from netfabbtrayhandler: " .. tostring(tray_to_check))
    end
end

if not tray_to_check and _G.tray then
    tray_to_check = _G.tray
    log("Got tray from global variable 'tray'")
end

if tray_to_check then
    local mt = getmetatable(tray_to_check)
    if mt then
        for k, v in pairs(mt) do
             -- Log anything that looks like save/export
             if string.find(k, "save") or string.find(k, "export") or string.find(k, "write") or string.find(k, "3mf") then
                 log("tray:" .. k)
             end
        end
    else
        log("Tray has no metatable accessible.")
        -- Manual check for expected methods
        local candidates = {"saveto3mf", "export", "save", "write", "saveproject"}
        for _, name in ipairs(candidates) do
            if tray_to_check[name] then
                log("Found property/method: tray." .. name)
            end
        end
    end
else
    log("No tray object found to inspect.")
end

-- 3. Inspect FabbProject
log("\n[Checking FabbProject]")
if _G.fabbproject then
    local mt = getmetatable(fabbproject)
    if mt then
         for k, v in pairs(mt) do
             if string.find(k, "save") or string.find(k, "export") then
                 log("fabbproject:" .. k)
             end
         end
    end
else
    log("fabbproject global is nil.")
end

log("--- Diagnostic End ---")
if f then f:close() end
