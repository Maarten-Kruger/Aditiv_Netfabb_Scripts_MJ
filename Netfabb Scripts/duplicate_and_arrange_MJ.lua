-- duplicate_and_arrange_MJ.lua
-- Duplicates a part in every tray to fill the tray and arranges them (True Shape).

local tray_percentage = 0.6 -- Percentage of tray area to fill (0.0 to 1.0)
local is_cylinder = true   -- Set to true if the build platform is cylindrical
local log_file_path = "C:\\Program Files\\Autodesk\\Netfabb 2026\\Examples"


-- Helper for logging
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
    print(msg)
    if f_log then
        f_log:write(tostring(msg) .. "\n")
        f_log:flush()
    end
end

log("Log file location: " .. log_file_path)

-- Function to process a single tray
local function process_tray(current_tray, tray_name, master_template_mesh, master_template_matrix)
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
    elseif master_template_mesh then
        -- Use Master Template if tray is empty
        log("Tray is empty. Using Master Template.")
        local new_luamesh = master_template_mesh:dupe()
        -- Apply original matrix to the geometry (baking it)
        if master_template_matrix then
            new_luamesh:applymatrix(master_template_matrix)
        end
        template_part = root:addmesh(new_luamesh)
        template_part.name = "Template Part"
    end

    if not template_part then
        log("No parts found in " .. tray_name .. " and no Master Template available. Skipping.")
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

            -- Apply the matrix to the geometry itself before adding to tray.
            new_luamesh:applymatrix(original_matrix)

            local new_traymesh = root:addmesh(new_luamesh)
            new_traymesh.name = template_part.name .. " (" .. i .. ")"

            table.insert(parts_to_arrange, new_traymesh)
        end
    else
        log("No duplicates needed (Tray full or part too big).")
    end

end

-- Main Execution Logic
log("--- Script Started ---")
log("Checking for 'fabbproject'...")

if fabbproject then
    log("'fabbproject' found. Tray Count: " .. fabbproject.traycount)
    if fabbproject.traycount == 0 then
        log("Warning: Project has no trays.")
    end

    -- Find Master Template (from first non-empty tray)
    local master_template_mesh = nil
    local master_template_matrix = nil

    for i = 0, fabbproject.traycount - 1 do
        local t = fabbproject:gettray(i)
        if t and t.root and t.root.meshcount > 0 then
            local first_mesh = t.root:getmesh(0)
            master_template_mesh = first_mesh.mesh
            master_template_matrix = first_mesh.matrix
            log("Found Master Template in Tray " .. (i + 1))
            break
        end
    end

    for i = 0, fabbproject.traycount - 1 do
        local t = fabbproject:gettray(i)
        if t then
            process_tray(t, "Tray " .. (i + 1), master_template_mesh, master_template_matrix)
        else
            log("Error: Failed to retrieve Tray " .. (i + 1))
        end
    end
else
    log("'fabbproject' is nil. Checking global 'tray'...")
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

if f_log then
    f_log:close()
end

log("--- Script Complete ---")
