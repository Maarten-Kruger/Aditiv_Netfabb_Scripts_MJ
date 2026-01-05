--[[
  Robust Netfabb Renamer (Fixed)
  - Enumerates top-level parts (Meshes and Subgroups) from tray.root
  - Sorts bottom->top (Row), then left->right (Column)
  - Renames parts uniquely: 001_BaseName, etc.
--]]

local logFilePath   = "C:\\Users\\Public\\Documents\\netfabb_script_log.txt"
local rowTolerance  = 2.0   -- in mm

-- Logging
if system and system.logtofile then
    system:logtofile(logFilePath)
end

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- Safe execution helper
local function safe_get(func)
    local ok, res = pcall(func)
    if ok then return res else return nil end
end

log("--- Robust Netfabb Renamer START ---")

if tray == nil then
    log("ERROR: tray variable not available.")
    return
end

local root = tray.root
if not root then
    log("ERROR: tray.root not available.")
    return
end

-- Helper to safely get AABB of a part (Mesh or Group)
local function get_part_aabb(part)
    -- Try direct min/max properties (common in Netfabb Lua)
    local ok, retMin = pcall(function() return part.min end)
    local ok2, retMax = pcall(function() return part.max end)

    if ok and ok2 and retMin and retMax then
        return retMin, retMax
    end

    -- If no direct min/max, try to calculate from children (if group)
    local inf = 1e9
    local calculatedMin = {x=inf, y=inf, z=inf}
    local calculatedMax = {x=-inf, y=-inf, z=-inf}
    local foundChild = false

    local function expand(boxMin, boxMax)
        foundChild = true
        if boxMin.x < calculatedMin.x then calculatedMin.x = boxMin.x end
        if boxMin.y < calculatedMin.y then calculatedMin.y = boxMin.y end
        if boxMin.z < calculatedMin.z then calculatedMin.z = boxMin.z end
        if boxMax.x > calculatedMax.x then calculatedMax.x = boxMax.x end
        if boxMax.y > calculatedMax.y then calculatedMax.y = boxMax.y end
        if boxMax.z > calculatedMax.z then calculatedMax.z = boxMax.z end
    end

    -- Recurse
    local mc = safe_get(function() return part.meshcount end)
    if mc then
        for i = 0, mc - 1 do
             local m = part:getmesh(i)
             if m then
                 local mMin, mMax = get_part_aabb(m)
                 if mMin and mMax then expand(mMin, mMax) end
             end
        end
    end

    local sc = safe_get(function() return part.subgroupcount end)
    if sc then
        for i = 0, sc - 1 do
             local g = part:getsubgroup(i)
             if g then
                 local gMin, gMax = get_part_aabb(g)
                 if gMin and gMax then expand(gMin, gMax) end
             end
        end
    end

    if foundChild then
        return calculatedMin, calculatedMax
    end

    -- Fallback: Try center and assume small size or just use center as min/max
    local okC, center = pcall(function() return part.center end)
    if okC and center then
        return center, center -- Point size
    end

    return nil, nil
end

-- Collect Top-Level Parts
local parts = {}

-- 1. Meshes
local meshCount = safe_get(function() return root.meshcount end)
if meshCount then
    for i = 0, meshCount - 1 do
        local m = root:getmesh(i)
        if m then
            table.insert(parts, {obj = m, type = "mesh", tag = "mesh_"..i})
        end
    end
else
    log("Note: root.meshcount not accessible or nil.")
end

-- 2. Subgroups (Parts with supports or groups)
local subgroupCount = safe_get(function() return root.subgroupcount end)
if subgroupCount then
    for i = 0, subgroupCount - 1 do
        local g = root:getsubgroup(i)
        if g then
            table.insert(parts, {obj = g, type = "group", tag = "group_"..i})
        end
    end
else
    log("Note: root.subgroupcount not accessible or nil.")
end

log(string.format("Found %d top-level parts.", #parts))

if #parts == 0 then
    log("No parts found (or enumeration failed).")
    return
end

-- Calculate Positions
local partsWithPos = {}
for i, p in ipairs(parts) do
    local min, max = get_part_aabb(p.obj)
    if min and max then
        -- We use center of bounding box for sorting
        local cx = (min.x + max.x) / 2
        local cy = (min.y + max.y) / 2

        table.insert(partsWithPos, {part = p.obj, x = cx, y = cy, tag = p.tag})
    else
        log("WARNING: Could not determine position for " .. p.tag)
    end
end

-- Sort
-- Group by Rows (Y)
-- Sort by Y first.
table.sort(partsWithPos, function(a,b) return a.y < b.y end)

-- Assign row indices
if #partsWithPos > 0 then
    local currentRowY = partsWithPos[1].y
    local currentRow = 1
    partsWithPos[1].row = currentRow

    for i = 2, #partsWithPos do
        local p = partsWithPos[i]
        if math.abs(p.y - currentRowY) > rowTolerance then
            currentRow = currentRow + 1
            currentRowY = p.y
        end
        p.row = currentRow
    end
end

-- Sort by Row then X
table.sort(partsWithPos, function(a,b)
    if a.row ~= b.row then
        return a.row < b.row -- Bottom to Top (ascending Y)
    else
        return a.x < b.x -- Left to Right (ascending X)
    end
end)

-- Rename
local renamed = 0
for i, p in ipairs(partsWithPos) do
    local oldName = p.part.name or "Part"
    -- Strip existing prefix NNN_
    local baseName = oldName:gsub("^%d%d%d_", "")
    local newName = string.format("%03d_%s", i, baseName)

    p.part.name = newName
    log(string.format("Renamed %s -> %s (Row=%d, X=%.2f, Y=%.2f)", oldName, newName, p.row, p.x, p.y))
    renamed = renamed + 1
end

log("Renaming complete. Total renamed: " .. renamed)

if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

log("--- Robust Netfabb Renamer END ---")
