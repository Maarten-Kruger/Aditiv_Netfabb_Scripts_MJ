-- rename_ordered.lua
-- Renames parts from Left-Bottom to Top-Right
-- Priority: Bottom to Top (Y), then Left to Right (X)
-- Handles individual meshes and groups (parts with supports)

-- Config
local rowTolerance = 2.0 -- mm

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

local function safeExec(f)
    local ok, res = pcall(f)
    if ok then return res end
    return nil
end

if _G.tray == nil then
    log("ERROR: _G.tray not available. Run from Main Lua Automation with an active build room.")
    return
end

local tray = _G.tray
local root = tray.root

log("--- Starting Rename Ordered Script ---")

-- 1. Collect Top-Level Entities (Meshes and Groups)
local entities = {}

-- Collect Subgroups (Groups) - these are likely parts with supports
local sc = safeExec(function() return root.subgroupcount end) or 0
for i = 0, sc - 1 do
    local grp = safeExec(function() return root:getsubgroup(i) end)
    if grp then
        table.insert(entities, { obj = grp, type = "group", index = i })
    end
end

-- Collect Meshes - these are likely individual parts
local mc = safeExec(function() return root.meshcount end) or 0
for i = 0, mc - 1 do
    local mesh = safeExec(function() return root:getmesh(i) end)
    if mesh then
        table.insert(entities, { obj = mesh, type = "mesh", index = i })
    end
end

log(string.format("Found %d entities (%d subgroups, %d meshes)", #entities, sc, mc))

if #entities == 0 then
    log("No entities found to rename.")
    return
end

-- 2. Detect Matrix Convention (Robust detection logic)
local valsA = {minx=1e9,maxx=-1e9,miny=1e9,maxy=-1e9, count=0}
local valsB = {minx=1e9,maxx=-1e9,miny=1e9,maxy=-1e9, count=0}

for _, e in ipairs(entities) do
    local mat = safeExec(function() return e.obj.matrix end)
    if mat then
        -- Convention A: 3,0 / 3,1
        local xa = safeExec(function() return mat:get(3,0) end)
        local ya = safeExec(function() return mat:get(3,1) end)
        if xa and ya and type(xa) == "number" and type(ya) == "number" then
            valsA.count = valsA.count + 1
            if xa < valsA.minx then valsA.minx = xa end
            if xa > valsA.maxx then valsA.maxx = xa end
            if ya < valsA.miny then valsA.miny = ya end
            if ya > valsA.maxy then valsA.maxy = ya end
        end

        -- Convention B: 0,3 / 1,3
        local xb = safeExec(function() return mat:get(0,3) end)
        local yb = safeExec(function() return mat:get(1,3) end)
        if xb and yb and type(xb) == "number" and type(yb) == "number" then
            valsB.count = valsB.count + 1
            if xb < valsB.minx then valsB.minx = xb end
            if xb > valsB.maxx then valsB.maxx = xb end
            if yb < valsB.miny then valsB.miny = yb end
            if yb > valsB.maxy then valsB.maxy = yb end
        end
    end
end

local rangeA = (valsA.count > 0) and ((valsA.maxx - valsA.minx) + (valsA.maxy - valsA.miny)) or 0
local rangeB = (valsB.count > 0) and ((valsB.maxx - valsB.minx) + (valsB.maxy - valsB.miny)) or 0

local chosenConv = "A"
if rangeB > rangeA then
    chosenConv = "B"
end
log("Chosen matrix convention: " .. chosenConv)

-- 3. Calculate Positions
local sortedEntities = {}
local minX, maxX, minY, maxY = 1e9, -1e9, 1e9, -1e9

for _, e in ipairs(entities) do
    local x, y
    local mat = safeExec(function() return e.obj.matrix end)

    if mat then
        if chosenConv == "A" then
            x = safeExec(function() return mat:get(3,0) end)
            y = safeExec(function() return mat:get(3,1) end)
        else
            x = safeExec(function() return mat:get(0,3) end)
            y = safeExec(function() return mat:get(1,3) end)
        end
    end

    -- Fallback to center if matrix fails
    if (x == nil or y == nil) then
         local c = safeExec(function() return e.obj.center end)
         if c and type(c.x) == "number" and type(c.y) == "number" then
             x = c.x
             y = c.y
         end
    end

    if x and y then
        e.x = x
        e.y = y
        table.insert(sortedEntities, e)

        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
    else
        log("WARNING: Could not determine position for entity " .. tostring(safeExec(function() return e.obj.name end)))
        e.x = 0
        e.y = 0
        table.insert(sortedEntities, e)
    end
end

-- Detect Units (Meters vs mm)
local maxAbs = math.max(math.abs(minX), math.abs(maxX), math.abs(minY), math.abs(maxY))
local unitFactor = 1.0
if maxAbs > 0 and maxAbs < 10 then
    unitFactor = 1000.0
    log("Detected meters, converting to mm for sorting logic.")
end

-- Assign Row Keys
for _, e in ipairs(sortedEntities) do
    local y_mm = e.y * unitFactor
    e.rowKey = math.floor(y_mm / rowTolerance + 0.5)
end

-- 4. Sort
-- Primary: Bottom to Top (Y Ascending)
-- Secondary: Left to Right (X Ascending)
table.sort(sortedEntities, function(a, b)
    if a.rowKey ~= b.rowKey then
        return a.rowKey < b.rowKey
    else
        return a.x < b.x
    end
end)

-- 5. Rename
local count = 0
for i, e in ipairs(sortedEntities) do
    local oldName = safeExec(function() return e.obj.name end) or "Part"

    -- Strip existing prefix NNN_ or NN_
    local baseName = oldName:gsub("^%d+_", "")

    -- Safety checks
    if baseName == "" or baseName == nil then
        -- If the name was purely numbers like "001", gsub might make it empty.
        -- In that case, keep original or default to "Part"
        if oldName ~= "" then
            baseName = oldName
        else
            baseName = "Part"
        end
    end

    local newName = string.format("%03d_%s", i + 1, baseName) -- 1-based index: 001_...

    local ok = pcall(function() e.obj.name = newName end)
    if ok then
        count = count + 1
        log(string.format("Renamed: %s -> %s (X=%.2f, Y=%.2f)", oldName, newName, e.x, e.y))
    else
        log("Failed to rename: " .. oldName)
    end
end

log("Renamed " .. count .. " entities.")

if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

log("--- End Rename Ordered Script ---")
