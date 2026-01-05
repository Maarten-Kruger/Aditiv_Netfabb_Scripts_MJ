--[[
  Custom Support Generation Script
  
  This script analyzes mesh surfaces and generates "supports" (represented as markers)
  for surfaces that exceed a critical angle.
  
  Configuration:
  - critical_angle_deg: Angle from vertical (0 = vertical wall, 90 = horizontal overhang).
    If a surface normal is further from vertical than this, support is needed.
    (Commonly: 45 degrees)
    
  LIMITATIONS:
  - This script assumes access to mesh topology (triangles/vertices). 
    Since the exact API for 'gettriangle' varies by Netfabb version and is not readable 
    without the binary docs, this script uses 'pcall' to attempt standard method names.
  - "Supports" are generated as simple box primitives or logged, as full support tree generation 
    is complex and usually handled by the built-in 'support' module (accessible via GUI).
--]]

local critical_angle_deg = 45.0
local logFilePath = "C:\\Users\\Public\\Documents\\netfabb_support_log.txt"

-- Setup Logging
if system and system.logtofile then
    system:logtofile(logFilePath)
end

local function log(msg)
    if system and system.log then system:log(msg) end
    print(msg)
end

log("--- Custom Support Generation Script Started ---")

-- Helper: Safe API Call
local function safe_call(func, ...)
    local args = {...}
    local ok, res = pcall(function() return func(unpack(args)) end)
    if ok then return res else return nil end
end

-- Helper: Safe Property Access
-- Netfabb UserData objects often throw errors instead of returning nil for missing properties
local function safe_get_property(obj, propName)
    local ok, res = pcall(function() return obj[propName] end)
    if ok then return res else return nil end
end

-- Math Helpers
local function normalize(x, y, z)
    local len = math.sqrt(x*x + y*y + z*z)
    if len > 0 then
        return x/len, y/len, z/len
    else
        return 0, 0, 1
    end
end

local function dot_product(x1, y1, z1, x2, y2, z2)
    return x1*x2 + y1*y2 + z1*z2
end

local function rad2deg(rad)
    return rad * (180 / math.pi)
end

-- Support Creation Stub
local function create_support_marker(x, y, z)
    log(string.format("  -> Creating support marker at (%.2f, %.2f, %.2f)", x, y, z))
    
    -- Attempt to create a box/primitive if API allows.
    -- Assuming system:addbox or similar might exist.
    -- If not, this is just a log.
    
    local size = 1.0
    -- Hypothetical API call:
    if system and system.createbox then
        pcall(function() 
            system:createbox(x - size/2, y - size/2, 0, size, size, z) 
        end)
    end
end

-- Mesh Analysis
local function analyze_mesh(mesh)
    log("Analyzing mesh...")
    
    -- 1. Determine Triangle Count
    local tri_count = 0
    -- Try different property names safely
    tri_count = safe_get_property(mesh, "trianglecount") 
             or safe_get_property(mesh, "count") 
             or safe_get_property(mesh, "facecount")
             or 0
             
    if tri_count == 0 then
        -- Try method
        local tc = safe_call(function() return mesh:gettrianglecount() end)
        if tc then tri_count = tc end
    end
    
    if tri_count == 0 then
        log("No triangles found or API mismatch for triangle count.")
        return
    end
    
    log("Found " .. tri_count .. " triangles.")
    
    -- 2. Iterate Triangles
    local supports_needed = 0
    
    for i = 0, tri_count - 1 do
        -- Attempt to get triangle data
        -- Assumption: gettriangle returns 3 vertices (each has x,y,z) OR 3 indices
        -- OR gettriangle returns v1x, v1y, v1z, v2x, ...
        
        -- Let's try to get a Normal directly if possible
        -- local nx, ny, nz = mesh:gettrianglenormal(i) 
        
        -- Fallback: Calculate from vertices
        -- We need 3 vertices.
        -- Standard Netfabb Lua might use: mesh:gettriangle(i) -> v1, v2, v3 (Point objects)
        
        local ok, v1, v2, v3 = pcall(function() return mesh:gettriangle(i) end)
        
        if ok and v1 and v2 and v3 then
            -- Assume v1 has .x, .y, .z
            local ux, uy, uz = v2.x - v1.x, v2.y - v1.y, v2.z - v1.z
            local vx, vy, vz = v3.x - v1.x, v3.y - v1.y, v3.z - v1.z
            
            -- Cross product for normal
            local nx = uy*vz - uz*vy
            local ny = uz*vx - ux*vz
            local nz = ux*vy - uy*vx
            
            nx, ny, nz = normalize(nx, ny, nz)
            
            -- Check angle with -Z (Down)
            -- Angle with vertical (0,0,-1)
            -- Cos(theta) = dot(n, down)
            local down_x, down_y, down_z = 0, 0, -1
            local dot = dot_product(nx, ny, nz, down_x, down_y, down_z)
            
            -- If dot > 0, the face is pointing somewhat down.
            -- dot = 1 -> Straight down (0 degrees from vertical down)
            -- dot = 0 -> Vertical wall (90 degrees from vertical down)
            
            if dot > 0 then
                local angle_rad = math.acos(dot) -- Angle from straight down
                local angle_deg = rad2deg(angle_rad)
                
                if angle_deg < critical_angle_deg then
                    -- Centroid
                    local cx = (v1.x + v2.x + v3.x) / 3
                    local cy = (v1.y + v2.y + v3.y) / 3
                    local cz = (v1.z + v2.z + v3.z) / 3
                    
                    create_support_marker(cx, cy, cz)
                    supports_needed = supports_needed + 1
                end
            end
        end
    end
    
    log("Analysis complete. Generated " .. supports_needed .. " support markers.")
end

-- Main Execution
if tray then
    local root = nil
    -- Safely access tray.root
    local ok_root, r = pcall(function() return tray.root end)
    if ok_root then root = r end
    
    if root then
        -- 1. Try iterating via tray.root.itemcount (Tree items)
        local items = safe_get_property(root, "itemcount")
        
        if items and items > 0 then
            log("Scanning " .. items .. " items in tray via root:getitem()...")
            for i = 0, items - 1 do
                local item = safe_call(function() return root:getitem(i) end)
                if item then
                     -- Check if item is a mesh or has a mesh
                    local mesh = nil
                    
                    -- Try getmesh
                    local m = safe_call(function() return item:getmesh(0) end)
                    if m then 
                        mesh = m 
                    elseif safe_get_property(item, "trianglecount") then
                        -- item itself might be the mesh
                        mesh = item
                    end
                    
                    if mesh then
                        analyze_mesh(mesh)
                    end
                end
            end
        else
            -- 2. Fallback: Try system.getPartCount() (Global part list)
            log("tray.root.itemcount unavailable or 0. Trying system.getPartCount()...")
            local sys_part_count = safe_call(function() return system.getPartCount() end) or 0
            
            if sys_part_count > 0 then
                log("Found " .. sys_part_count .. " parts via system.getPartCount().")
                for i = 0, sys_part_count - 1 do
                    local part = safe_call(function() return system.getPart(i) end)
                    if part then
                         -- Part might be a group, mesh, or wrapper.
                         -- Try to treat as mesh first
                         analyze_mesh(part)
                    end
                end
            else
                log("No parts found via system.getPartCount() either.")
            end
        end
    else
         log("Error: tray.root is not available.")
    end
else
    log("Error: 'tray' global not found.")
end

if application then
    local ok = pcall(function() application:triggerdesktopevent('updateparts') end)
end
