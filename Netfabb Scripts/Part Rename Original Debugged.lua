--[[
  Robust Netfabb Renamer
  - Enumerates placed parts (tries items, mesh instances, meshes)
  - Auto-detects matrix translation convention and units (m vs mm)
  - Groups rows by configurable tolerance (mm) and sorts bottom->top, left->right
  - Renames every placement uniquely: 001_BaseName, 002_BaseName, ...
  - Logs diagnostics to C:\Users\Public\Documents\netfabb_script_log.txt
--]]

-- === CONFIG ===
local logFilePath   = "C:\\Users\\Public\\Documents\\netfabb_script_log.txt"
local rowTolerance  = 2.0   -- in mm: change if your rows have different spacing
-- =============

local function safeExec(f)
    local ok, res = pcall(f)
    if ok then return res end
    return nil
end

system:logtofile(logFilePath)
system:log("--- Robust Netfabb Renamer START ---")
system:log("Row tolerance (mm): " .. tostring(rowTolerance))

if _G.tray == nil then
    system:log("ERROR: _G.tray not available. Run from Main Lua Automation with an active build room.")
    return
end
local tray = _G.tray
system:log("Active platform: " .. tostring(tray.name))

-- Helper: enumerate meshes (basic)
local function enum_meshes()
    local list = {}
    local mc = safeExec(function() return tray.root.meshcount end) or 0
    for i = 0, mc-1 do
        local okMesh = safeExec(function() return tray.root:getmesh(i) end)
        if okMesh then
            table.insert(list, {obj = okMesh, tag = string.format("mesh[%d]", i)})
        end
    end
    return list
end

-- Helper: enumerate tray items (if available)
local function enum_items()
    local list = {}
    local ic = safeExec(function() return tray.root.itemcount end)
    if not ic or ic == 0 then return list end
    for i = 0, ic-1 do
        local it = safeExec(function() return tray.root:getitem(i) end)
        if it then
            table.insert(list, {obj = it, tag = string.format("item[%d]", i)})
        end
    end
    return list
end

-- Helper: enumerate mesh instances (if meshes expose instances)
local function enum_mesh_instances()
    local list = {}
    local mc = safeExec(function() return tray.root.meshcount end) or 0
    for i = 0, mc-1 do
        local m = safeExec(function() return tray.root:getmesh(i) end)
        if m then
            local ic = safeExec(function() return m.instancecount end)
            if ic and ic > 0 then
                for j = 0, ic-1 do
                    local inst = safeExec(function() return m:getinstance(j) end)
                    if inst then
                        table.insert(list, {obj = inst, tag = string.format("mesh[%d].instance[%d]", i, j)})
                    end
                end
            end
        end
    end
    return list
end

-- Helper: enumerate using system.getPart (fallback/robust method)
local function enum_system_parts()
    local list = {}
    local pc = safeExec(function() return system.getPartCount() end) or 0
    for i = 0, pc-1 do
        local part = safeExec(function() return system.getPart(i) end)
        if part then
            table.insert(list, {obj = part, tag = string.format("system.part[%d]", i)})
        end
    end
    return list
end

system:log("Attempting multiple enumeration strategies...")

local lists = {
    {name = "items",         list = enum_items()},
    {name = "mesh_instances",list = enum_mesh_instances()},
    {name = "meshes",        list = enum_meshes()},
    {name = "system_parts",  list = enum_system_parts()}
}

-- Log counts and pick the largest result (most likely the actual placements)
local best = nil
for _, entry in ipairs(lists) do
    system:log(string.format("Found %d entries using '%s' enumeration.", #entry.list, entry.name))
    if best == nil or #entry.list > #best.list then best = entry end
end

if best == nil or #best.list == 0 then
    system:log("ERROR: No parts found by any enumeration strategy. Aborting.")
    return
end

system:log(string.format("Using enumeration method: '%s' (count=%d)", best.name, #best.list))

-- Deduplicate by tostring(obj) to avoid double-counting same userdata in some APIs
local uniqueMap = {}
local parts = {}
for _, e in ipairs(best.list) do
    local key = tostring(e.obj)
    system:log(string.format("Candidate %s: type=%s key=%s", e.tag, type(e.obj), key))
    if not uniqueMap[key] then
        uniqueMap[key] = true
        table.insert(parts, {obj = e.obj, tag = e.tag})
    end
end

system:log(string.format("Unique placements selected: %d", #parts))

-- === Detect matrix translation convention (two common conventions) ===
-- Convention A: matrix:get(3,0) , matrix:get(3,1)
-- Convention B: matrix:get(0,3) , matrix:get(1,3)
local valsA = {minx=1e9,maxx=-1e9,miny=1e9,maxy=-1e9, count=0}
local valsB = {minx=1e9,maxx=-1e9,miny=1e9,maxy=-1e9, count=0}

for _, p in ipairs(parts) do
    local mat = safeExec(function() return p.obj.matrix end)
    if mat then
        local xa = safeExec(function() return mat:get(3,0) end)
        local ya = safeExec(function() return mat:get(3,1) end)
        if xa and ya and type(xa) == "number" and type(ya) == "number" then
            valsA.count = valsA.count + 1
            if xa < valsA.minx then valsA.minx = xa end
            if xa > valsA.maxx then valsA.maxx = xa end
            if ya < valsA.miny then valsA.miny = ya end
            if ya > valsA.maxy then valsA.maxy = ya end
        end

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

local rangeA = 0
if valsA.count > 0 then rangeA = (valsA.maxx - valsA.minx) + (valsA.maxy - valsA.miny) end
local rangeB = 0
if valsB.count > 0 then rangeB = (valsB.maxx - valsB.minx) + (valsB.maxy - valsB.miny) end

system:log(string.format("ConventionA count=%d range=%.6f ; ConventionB count=%d range=%.6f",
    valsA.count, rangeA, valsB.count, rangeB))

local chosenConv = nil
if valsA.count == 0 and valsB.count == 0 then
    system:log("ERROR: No usable matrix translations found. Aborting.")
    return
elseif rangeA >= rangeB then
    chosenConv = "A" -- use mat:get(3,0)/(3,1)
else
    chosenConv = "B" -- use mat:get(0,3)/(1,3)
end

system:log("Chosen matrix translation convention: " .. chosenConv)

-- Build partsWithPositions using chosen convention
local partsWithPos = {}
local minX, maxX, minY, maxY = 1e9, -1e9, 1e9, -1e9
for idx, p in ipairs(parts) do
    local partObj = p.obj
    local mat = safeExec(function() return partObj.matrix end)
    local x,y = nil,nil
    if mat then
        if chosenConv == "A" then
            x = safeExec(function() return mat:get(3,0) end)
            y = safeExec(function() return mat:get(3,1) end)
        else
            x = safeExec(function() return mat:get(0,3) end)
            y = safeExec(function() return mat:get(1,3) end)
        end
        if x and y then system:log(string.format("Used 'matrix' convention %s for %s", chosenConv, p.tag)) end
    end

    -- fallback: if matrix not present, try partObj.center (some APIs)
    if (not x or not y) and safeExec(function() return partObj.center end) then
        local c = safeExec(function() return partObj.center end)
        if c and type(c.x) == "number" and type(c.y) == "number" then
            x = c.x; y = c.y
            system:log(string.format("Used 'center' property for %s", p.tag))
        end
    end

    -- fallback: try getOutbox (reliable for meshes/groups)
    if (not x or not y) then
        local box = safeExec(function() return partObj:getOutbox() end)
        if box and box.min and box.max and type(box.min.x)=="number" and type(box.max.x)=="number" then
            x = (box.min.x + box.max.x) / 2
            y = (box.min.y + box.max.y) / 2
            system:log(string.format("Used 'getOutbox' for %s", p.tag))
        end
    end

    if x and y and type(x) == "number" and type(y) == "number" then
        table.insert(partsWithPos, {part = partObj, x = x, y = y, tag = p.tag})
        if x < minX then minX = x end
        if x > maxX then maxX = x end
        if y < minY then minY = y end
        if y > maxY then maxY = y end
        system:log(string.format("Candidate %s -> raw coords (%.6f, %.6f)", p.tag, x, y))
    else
        system:log(string.format("WARNING: Could not read coords for %s; skipping", p.tag))
    end
end

if #partsWithPos == 0 then
    system:log("ERROR: No placements with valid coordinates found. Aborting.")
    return
end

-- Detect units: if ranges are small (< 10) assume meters, else mm
local maxAbs = math.max(math.abs(minX), math.abs(maxX), math.abs(minY), math.abs(maxY))
local unitFactor = 1.0
local unitNote = "mm"
if maxAbs > 0 and maxAbs < 10 then
    -- values look like meters -> convert to mm
    unitFactor = 1000.0
    unitNote = "meters->converted_to_mm"
    system:log(string.format("Detected small coordinate magnitudes (maxAbs=%.6f) -> assuming meters, converting *1000 to mm.", maxAbs))
else
    system:log(string.format("Detected coordinates appear to be in mm or large units (maxAbs=%.6f) -> using as mm.", maxAbs))
end

-- Apply conversion and compute row keys
for _, p in ipairs(partsWithPos) do
    p.x = p.x * unitFactor
    p.y = p.y * unitFactor
    -- compute integer row key by rounding to nearest rowTolerance
    p.rowKey = math.floor(p.y / rowTolerance + 0.5)
end

-- Sort by row (ascending = bottom->top) then by x (ascending = left->right)
table.sort(partsWithPos, function(a,b)
    if a.rowKey ~= b.rowKey then
        return a.rowKey < b.rowKey
    else
        return a.x < b.x
    end
end)

system:log(string.format("Sorting complete. Using rowTolerance=%.2f mm. Unit handling: %s", rowTolerance, unitNote))

-- Rename sequentially; remove existing numeric prefix of any length (NNN_)
local renamed = 0
for i, p in ipairs(partsWithPos) do
    local obj = p.part
    local oldName = safeExec(function() return obj.name end) or ""
    local base = oldName:gsub("^%d+_", "")
    if base == "" then base = "Part" end
    local newName = string.format("%03d_%s", i, base)
    local ok = pcall(function() obj.name = newName end)
    if ok then
        renamed = renamed + 1
        system:log(string.format("Renamed [%03d] %s -> %s  (X=%.2fmm Y=%.2fmm row=%d tag=%s)",
            i, oldName, newName, p.x, p.y, p.rowKey, p.tag))
    else
        system:log(string.format("ERROR: Failed to rename object (tag=%s). Tried name: %s", p.tag, newName))
    end
end

system:log(string.format("Finished renaming. Total processed: %d, renamed: %d", #partsWithPos, renamed))
system:log("--- Robust Netfabb Renamer END ---")

