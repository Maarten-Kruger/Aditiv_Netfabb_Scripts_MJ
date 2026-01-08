-- duplicate_and_arrange_MJ.lua
-- Duplicates a part in every tray to fill the tray and arranges them.

local tray_percentage = 0.8 -- Percentage of tray area to fill (0.0 to 1.0)
local is_cylinder = false   -- Set to true if the build platform is cylindrical

-- Helper for logging
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
    print(msg)
end

-- Function to process a single tray
local function process_tray(current_tray, tray_name)
    log("--- Processing " .. tray_name .. " ---")

    if not current_tray or not current_tray.root then
        log("Error: Tray root not available for " .. tray_name)
        return
    end

    local root = current_tray.root

    -- 1. Find a template part (first mesh found)
    local template_part = nil
    local mesh_count = root.meshcount

    if mesh_count > 0 then
        template_part = root:getmesh(0)
    end

    if not template_part then
        log("No parts found in " .. tray_name .. ". Skipping.")
        return
    end

    log("Template Part: " .. template_part.name)

    -- 2. Calculate Part Area
    local part_area = 0.0
    local luamesh = template_part.mesh

    -- Try mesh:outboxbasearea()
    local success, area = pcall(function() return luamesh:outboxbasearea() end)

    if success and area and area > 0 then
        part_area = area
        log("Part Area (from outboxbasearea): " .. part_area)
    else
        -- Fallback: Calculate from World Outbox
        local ob = nil
        pcall(function() ob = template_part.outbox end)

        if ob then
            local width = ob.maxx - ob.minx
            local depth = ob.maxy - ob.miny
            part_area = width * depth
            log("Part Area (calculated from outbox): " .. part_area)
        else
            log("Error: Could not retrieve bounding box.")
        end
    end

    -- Alternative: mesh:shadowarea() (Commented out)
    --[[
    local success_shadow, shadow_area = pcall(function() return luamesh:shadowarea() end)
    if success_shadow and shadow_area and shadow_area > 0 then
        part_area = shadow_area
        log("Part Area (from shadowarea): " .. part_area)
    end
    --]]

    if part_area <= 0 then
        log("Error: Could not calculate valid part area. Skipping tray.")
        return
    end

    -- 3. Calculate Tray Area
    local tray_area = 0.0
    local mx = current_tray.machinesize_x
    local my = current_tray.machinesize_y

    -- Check for cylinder/box
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

    -- 5. Duplicate the part
    local parts_to_arrange = {}
    table.insert(parts_to_arrange, template_part)

    if duplicates_needed > 0 then
        log("Duplicating part...")

        local original_matrix = template_part.matrix

        for i = 1, duplicates_needed do
            -- Create a duplicate of the geometry
            local new_luamesh = luamesh:dupe()

            -- FIX: Apply the matrix to the geometry itself before adding to tray.
            -- This bakes the transformation into the vertices.
            new_luamesh:applymatrix(original_matrix)

            local new_traymesh = root:addmesh(new_luamesh)
            new_traymesh.name = template_part.name .. " (" .. i .. ")"

            table.insert(parts_to_arrange, new_traymesh)
        end
    else
        log("No duplicates needed (Tray full or part too big).")
    end

    -- 6. Run 2D Packing
    log("Starting 2D Packing for " .. tray_name .. "...")

    -- Create Packer
    local packer_id = current_tray.packingid_2d
    if not packer_id then
        log("Warning: packingid_2d not found. Falling back to Monte Carlo.")
        packer_id = current_tray.packingid_montecarlo
    end

    local packer = nil
    if current_tray.createpacker then
        packer = current_tray:createpacker(packer_id)
    end

    if not packer then
        log("Error: Could not create packer for " .. tray_name)
        return
    end

    -- Configure Packer
    if packer_id == current_tray.packingid_2d then
        packer.rastersize = 1.0
        packer.anglecount = 4
        packer.placeoutside = true
        packer.borderspacingxy = 2.0
        packer.packonlyselected = false
    elseif packer_id == current_tray.packingid_montecarlo then
        packer.packing_quality = -1
        packer.start_from_current_positions = false
        packer.minimaldistance = 2.0
    end

    -- Set Restrictions: Lock everything EXCEPT our parts
    local current_mesh_count = root.meshcount
    for i = 0, current_mesh_count - 1 do
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
    log("Packing " .. tray_name .. " finished with result code: " .. tostring(errorcode))
end

-- Main Execution Logic
log("--- Script Started ---")

if fabbproject then
    log("Iterating through " .. fabbproject.traycount .. " trays in project.")
    for i = 0, fabbproject.traycount - 1 do
        local t = fabbproject:gettray(i)
        process_tray(t, "Tray " .. (i + 1))
    end
else
    if tray then
        process_tray(tray, "Current Tray")
    else
        log("Error: No global 'tray' or 'fabbproject' found.")
    end
end

-- Update GUI
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

log("--- Script Complete ---")
