--[[
  API Inspector / Discovery Script
  
  Run this script to dump the available methods and properties of the 
  Netfabb Lua objects (Part, Mesh, System) to a log file.
  This helps identifying the correct API calls for your version.
--]]

local logFilePath = "C:\\Users\\Public\\Documents\\netfabb_api_dump.txt"

if system and system.logtofile then
    system:logtofile(logFilePath)
end

local function log(msg)
    if system and system.log then system:log(msg) end
    print(msg)
end

log("--- API Inspector Start ---")

-- Helper to dump table/userdata
local function dump_obj(name, obj)
    log("Dumping " .. name .. " (" .. type(obj) .. "):")
    
    -- Try metatable
    local mt = getmetatable(obj)
    if mt then
        log("  Metatable found.")
        for k, v in pairs(mt) do
            log("  [MT] " .. tostring(k) .. ": " .. tostring(v))
        end
        -- Sometimes methods are in __index
        if mt.__index and type(mt.__index) == "table" then
             log("  __index table found:")
             for k, v in pairs(mt.__index) do
                 log("    " .. tostring(k))
             end
        end
    end
    
    -- Try pairs (often fails for userdata)
    local ok, err = pcall(function()
        for k, v in pairs(obj) do
             log("  [Key] " .. tostring(k) .. ": " .. tostring(v))
        end
    end)
    if not ok then log("  Cannot iterate pairs: " .. tostring(err)) end
end

-- Dump System
dump_obj("system", system)

-- Dump Tray/Root
if tray then
    dump_obj("tray", tray)
    if tray.root then
        dump_obj("tray.root", tray.root)
        
        -- Get first item
        if tray.root.getitem then
            local item = tray.root:getitem(0)
            if item then
                dump_obj("First Part (Item 0)", item)
                
                -- Get Mesh
                if item.getmesh then
                    local mesh = item:getmesh(0)
                    if mesh then
                        dump_obj("Mesh 0", mesh)
                    end
                end
            end
        end
    end
end

log("--- API Inspector End ---")
