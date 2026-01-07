--[[
  Robust Netfabb Renamer (Updated)
  - Enumerates top-level parts using tray.root:getitem(i)
  - Sorts bottom->top (Row), then left->right (Column)
  - Renames parts uniquely: 001_BaseName, etc.
--]]

local logFilePath   = "C:\\Users\\Public\\Documents\\netfabb_script_log.txt"
local rowTolerance  = 2.0   -- in mm

-- Logging setup
if system and system.logtofile then
    system:logtofile(logFilePath)
end

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
    -- Also try print for standard output capture if supported
    print(msg)
end

-- Safe execution helper
local function safe_get(func)
    local ok, res = pcall(func)
    if ok then return res else return nil end
end

log("--- Robust Netfabb Renamer DEBUG START ---")

if tray == nil then
    log("ERROR: tray variable not available.")
    return
end

local root = tray.root
if not root then
    log("ERROR: tray.root not available.")
    return
end

-- Helper to safely get AABB of a part
local function get_part_aabb(part)
    -- Try direct min/max properties
    local ok, retMin = pcall(function() return part.min end)
    local ok2, retMax = pcall(function() return part.max end)

    if ok and ok2 and retMin and retMax then
        return retMin, retMax
    end

    -- Fallback: Check for 'center' property
    local okC, retCenter = pcall(function() return part.center end)
    if okC and retCenter then
        -- Verify it has x, y, z
        if type(retCenter.x) == "number" and type(retCenter.y) == "number" then
             return retCenter, retCenter
        end
    end

    -- Fallback: Check for 'matrix' property
    local okM, mat = pcall(function() return part.matrix end)
    if okM and mat then
        -- Helper for matrix access
        local function get_val(m, r, c)
            local ok, val = pcall(function() return m:get(r, c) end)
            if ok and type(val) == "number" then return val end
            return nil
        end

        -- Convention A: (3,0), (3,1), (3,2) - Row Major translation at bottom
        local xA = get_val(mat, 3, 0)
        local yA = get_val(mat, 3, 1)
        local zA = get_val(mat, 3, 2)

        -- Convention B: (0,3), (1,3), (2,3) - Column Major translation at right
        local xB = get_val(mat, 0, 3)
        local yB = get_val(mat, 1, 3)
        local zB = get_val(mat, 2, 3)

        local function is_valid(v) return v ~= nil end
        local validA = is_valid(xA) and is_valid(yA)
        local validB = is_valid(xB) and is_valid(yB)

        -- Heuristic: Default to A (Netfabb standard often), unless B seems populated and A is not
        if validA and validB then
            -- Check magnitude? Or just pick A.
            local magA = math.abs(xA) + math.abs(yA)
            local magB = math.abs(xB) + math.abs(yB)
            if magB > magA + 0.0001 then -- If B has significantly more data?
                local v = {x=xB, y=yB, z=(zB or 0)}
                return v, v
            else
                local v = {x=xA, y=yA, z=(zA or 0)}
                return v, v
            end
        elseif validA then
            local v = {x=xA, y=yA, z=(zA or 0)}
            return v, v
        elseif validB then
            local v = {x=xB, y=yB, z=(zB or 0)}
            return v, v
        end
    end

    -- If no direct min/max, try recursive calculation
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

    -- Check children (meshes)
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

    -- Check children (subgroups)
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

    -- Check children (items - rare for parts but possible for groups)
    local ic = safe_get(function() return part.itemcount end)
    if ic then
         for i = 0, ic - 1 do
             local it = part:getitem(i)
             if it then
                 local iMin, iMax = get_part_aabb(it)
                 if iMin and iMax then expand(iMin, iMax) end
             end
         end
    end

    if foundChild then
        return calculatedMin, calculatedMax
    end

    return nil, nil
end

-- Collect Top-Level Parts using itemcount
local parts = {}
local itemCount = safe_get(function() return root.itemcount end)

if itemCount then
    log("Found root.itemcount: " .. itemCount)
    for i = 0, itemCount - 1 do
        local item = root:getitem(i)
        if item then
            local pName = safe_get(function() return item.name end) or "Unnamed"
            log(string.format("Checking Item %d: %s", i, pName))
            table.insert(parts, {obj = item, tag = "item_"..i, name = pName})
        else
            log(string.format("Item %d is nil", i))
        end
    end
else
    log("Note: root.itemcount failed or nil. Will attempt fallback enumeration.")
end

if #parts == 0 then
    log("No top-level parts found.")
    -- Attempt fallback for bare meshes if itemcount was 0
    local meshCount = safe_get(function() return root.meshcount end) or 0
    local subCount = safe_get(function() return root.subgroupcount end) or 0
    if meshCount > 0 or subCount > 0 then
        log(string.format("Fallback: Found %d meshes and %d subgroups.", meshCount, subCount))
         for i = 0, meshCount - 1 do
            local m = root:getmesh(i)
            if m then table.insert(parts, {obj = m, tag = "mesh_"..i}) end
        end
        for i = 0, subCount - 1 do
            local g = root:getsubgroup(i)
            if g then table.insert(parts, {obj = g, tag = "group_"..i}) end
        end
    end
end

log(string.format("Total parts to process: %d", #parts))

if #parts == 0 then
    log("Exiting: Nothing to rename.")
    return
end

-- Calculate Positions
local partsWithPos = {}
for i, p in ipairs(parts) do
    local min, max = get_part_aabb(p.obj)
    if min and max then
        local cx = (min.x + max.x) / 2
        local cy = (min.y + max.y) / 2
        table.insert(partsWithPos, {part = p.obj, x = cx, y = cy, tag = p.tag, name = p.name})
        log(string.format("Pos calculated for %s: (%.2f, %.2f)", p.tag, cx, cy))
    else
        log("WARNING: Could not determine position for " .. p.tag)
        -- Keep it but maybe put it at 0,0 or end?
        -- For now, skip sorting for it or handle gracefully
    end
end

-- Sort logic (Row then Column)
table.sort(partsWithPos, function(a,b) return a.y < b.y end)

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

table.sort(partsWithPos, function(a,b)
    if a.row ~= b.row then
        return a.row < b.row
    else
        return a.x < b.x
    end
end)

-- Rename
local renamedCount = 0
for i, p in ipairs(partsWithPos) do
    local oldName = p.part.name or "Part"
    local baseName = oldName:gsub("^%d%d%d_", "")
    local newName = string.format("%03d_%s", i, baseName)

    if oldName ~= newName then
        p.part.name = newName
        log(string.format("RENAME: %s -> %s", oldName, newName))
        renamedCount = renamedCount + 1
    else
        log(string.format("SKIP: %s already named correctly", oldName))
    end
end

log("Renaming complete. Modified: " .. renamedCount)

if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

log("--- Robust Netfabb Renamer END ---")
