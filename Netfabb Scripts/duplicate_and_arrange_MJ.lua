-- duplicate_and_arrange_MJ.lua
-- Duplicates the selected part to fill the tray and arranges them.

local tray_percentage = 0.8 -- Percentage of tray area to fill (0.0 to 1.0)
local is_cylinder = false   -- Set to true if the build platform is cylindrical

-- Helper for logging
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
    print(msg)
end

-- Check environment
if not tray or not tray.root then
    log("Error: 'tray' or 'tray.root' is not available.")
    return
end

local root = tray.root

-- 1. Find the selected part
local selected_part = nil
local mesh_count = root.meshcount

for i = 0, mesh_count - 1 do
    local mesh = root:getmesh(i)
    if mesh then
        local is_sel = false
        pcall(function() is_sel = mesh.selected end)
        if is_sel then
            selected_part = mesh
            break -- Process the first selected part
        end
    end
end

if not selected_part then
    log("Error: No part selected. Please select a part.")
    return
end

log("Selected Part: " .. selected_part.name)

-- 2. Calculate Part Area
local part_area = 0.0
local luamesh = selected_part.mesh

-- Try mesh:outboxbasearea() as requested
local success, area = pcall(function() return luamesh:outboxbasearea() end)

if success and area and area > 0 then
    part_area = area
    log("Part Area (from outboxbasearea): " .. part_area)
else
    -- Fallback: Calculate from World Outbox if the specific method is missing or fails
    -- Note: 'outbox' property on traymesh returns the world bounding box
    local ob = nil
    pcall(function() ob = selected_part.outbox end)

    if ob then
        local width = ob.maxx - ob.minx
        local depth = ob.maxy - ob.miny
        part_area = width * depth
        log("Part Area (calculated from outbox): " .. part_area)
    else
        log("Error: Could not retrieve bounding box.")
    end
end

-- Alternative: mesh:shadowarea() (Commented out as requested)
--[[
local success_shadow, shadow_area = pcall(function() return luamesh:shadowarea() end)
if success_shadow and shadow_area and shadow_area > 0 then
    part_area = shadow_area
    log("Part Area (from shadowarea): " .. part_area)
end
--]]

if part_area <= 0 then
    log("Error: Could not calculate valid part area.")
    return
end

-- 3. Calculate Tray Area
local tray_area = 0.0
local mx = tray.machinesize_x
local my = tray.machinesize_y

-- Check for cylinder/box
-- We use the 'is_cylinder' flag defined at top.
-- If user wants a popup, they can uncomment the following (if system:messagebox returns a value)
-- is_cylinder = system:messagebox("Is the tray cylindrical?", "Shape", 4) == 6 -- Pseudo-code: 4=YesNo, 6=Yes

if is_cylinder then
    -- Assuming mx is diameter
    local radius = mx / 2.0
    tray_area = math.pi * radius * radius
    log("Tray Area (Cylinder, Diameter=" .. mx .. "): " .. tray_area)
else
    tray_area = mx * my
    log("Tray Area (Box, " .. mx .. " x " .. my .. "): " .. tray_area)
end

-- 4. Calculate Max Parts
local target_fill_area = tray_area * tray_percentage
local max_count = math.floor(target_fill_area / part_area)
local duplicates_needed = max_count - 1

log("Target Fill Area: " .. target_fill_area .. " (" .. (tray_percentage * 100) .. "%)")
log("Max Parts: " .. max_count)
log("Duplicates Needed: " .. duplicates_needed)

if duplicates_needed < 1 then
    log("Tray is full or part is too large to duplicate. Continuing with arrangement.")
end

-- 5. Duplicate the part
local parts_to_arrange = {}
table.insert(parts_to_arrange, selected_part)

if duplicates_needed > 0 then
    log("Duplicating part...")

    -- We want to maintain the current orientation.
    -- If we duplicate the luamesh (geometry), it might be in local space.
    -- We apply the current transformation matrix to the new instances to match the original's position/orientation.

    local original_matrix = selected_part.matrix

    for i = 1, duplicates_needed do
        local new_luamesh = luamesh:dupe()
        local new_traymesh = root:addmesh(new_luamesh)
        new_traymesh.name = selected_part.name .. " (" .. i .. ")"

        -- Apply the original matrix to preserve orientation
        -- Assuming new_traymesh.matrix accepts assignment or we can use applymatrix on the mesh before adding?
        -- Standard Netfabb scripting: assign matrix property.
        new_traymesh.matrix = original_matrix

        table.insert(parts_to_arrange, new_traymesh)
    end
end

-- 6. Run 2D Packing
log("Starting 2D Packing...")

-- Create Packer
-- Using packingid_2d as requested ("simple arrange/pack 2D Packing function")
local packer_id = tray.packingid_2d

-- Fallback check
if not packer_id then
    log("Warning: packingid_2d not found. Falling back to Monte Carlo.")
    packer_id = tray.packingid_montecarlo
end

local packer = nil
if tray.createpacker then
    packer = tray:createpacker(packer_id)
end

if not packer then
    log("Error: Could not create packer.")
    return
end

-- Configure Packer
if packer_id == tray.packingid_2d then
    packer.rastersize = 1.0
    packer.anglecount = 4    -- 0, 90, 180, 270
    packer.placeoutside = true
    packer.borderspacingxy = 2.0
    packer.packonlyselected = false -- We manage restrictions manually
elseif packer_id == tray.packingid_montecarlo then
    packer.packing_quality = -1
    packer.start_from_current_positions = false
    packer.minimaldistance = 2.0
end

-- Set Restrictions: Lock everything EXCEPT our parts
-- Re-scan root.meshcount because we added parts
for i = 0, root.meshcount - 1 do
    local mesh = root:getmesh(i)

    -- Check if mesh is in our list
    local is_target = false
    for _, p in ipairs(parts_to_arrange) do
        if p == mesh then
            is_target = true
            break
        end
    end

    if is_target then
        mesh:setpackingoption('restriction', 'norestriction')
        mesh.selected = true
    else
        mesh:setpackingoption('restriction', 'locked')
        mesh.selected = false
    end
end

-- Execute Pack
local errorcode = packer:pack()
log("Packing finished with result code: " .. tostring(errorcode))

-- Update GUI
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

log("Script Complete.")
