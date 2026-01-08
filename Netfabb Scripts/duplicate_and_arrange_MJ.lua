-- duplicate_and_arrange_MJ.lua
-- Duplicates a part in every tray to fill the tray.
-- Modified by Jules

local tray_percentage = 0.6 -- Percentage of tray area to fill (0.0 to 1.0)
local is_cylinder = true   -- Set to true if the build platform is cylindrical
local log_file_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\duplicate_log.txt"

-- Setup Logging using system:logtofile
if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if not ok then
        if system.log then system:log("Failed to set log file: " .. tostring(err)) end
    end
end

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
    -- Fallback print
    print(msg)
end

log("--- Script Started ---")
log("Log file location: " .. log_file_path)

-- 1. Prompt for Directory containing .3mf files
local path_to_3mf = ""
local ok_browse, path = pcall(function() return system:browsedirectory("Select Directory containing .3mf files") end)

if ok_browse and path and path ~= "" then
    path_to_3mf = path
    -- Sanitize path (remove quotes)
    path_to_3mf = string.gsub(path_to_3mf, '"', '')
    -- Remove trailing slash if present
    if string.sub(path_to_3mf, -1) == "\\" then
        path_to_3mf = string.sub(path_to_3mf, 1, -2)
    end
    log("Selected 3MF Directory: " .. path_to_3mf)
else
    log("No directory selected. Exiting.")
    return
end


-- Function to process a single tray
local function process_tray(current_tray, tray_name)
    log("--- Processing " .. tray_name .. " ---")

    if not current_tray or not current_tray.root then
        log("Error: Tray root not available for " .. tray_name)
        return
    end

    local root = current_tray.root

    -- 1. Find a template part (must exist in tray)
    local template_part = nil
    if root.meshcount > 0 then
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

    -- 5. Duplicate the part (using 3MF import)
    if duplicates_needed > 0 then
        log("Duplicating part via 3MF import...")

        -- Determine the base name
        local base_name = template_part.name
        -- Remove common copy suffixes " (1)", " (2)", etc.
        base_name = string.gsub(base_name, "%s*%(%d+%)", "")
        -- Remove "_copy"
        base_name = string.gsub(base_name, "_copy", "")
        -- Remove file extension (e.g. .stl) if present at end
        base_name = string.gsub(base_name, "%.%w+$", "")
        -- Trim trailing whitespace
        base_name = string.gsub(base_name, "%s+$", "")

        local part_3mf_path = path_to_3mf .. "\\" .. base_name .. ".3mf"
        log("Constructed 3MF Path: " .. part_3mf_path)

        -- Try to import once to verify existence
        local verify_mesh = nil
        local success_verify, res_verify = pcall(function() return system:load3mf(part_3mf_path) end)

        if success_verify and res_verify then
            verify_mesh = res_verify
        else
            log("Error: Could not load 3MF file at: " .. part_3mf_path)
            log("Details: " .. tostring(res_verify))
            return -- Cannot proceed with duplication for this part
        end

        -- If verification passed, we can't necessarily re-use 'verify_mesh' multiple times if adding it consumes it or if we need distinct objects.
        -- Usually system:load3mf returns a new LuaMesh each time.
        -- Let's use the first one we loaded.
        if verify_mesh then
             local new_traymesh = root:addmesh(verify_mesh)
             new_traymesh.name = base_name .. " (1)"
             log("Imported copy 1")
        end

        -- Loop for the rest
        for i = 2, duplicates_needed do
            local imported_mesh = nil
            local success, res = pcall(function() return system:load3mf(part_3mf_path) end)

            if success and res then
                imported_mesh = res
                local new_traymesh = root:addmesh(imported_mesh)
                new_traymesh.name = base_name .. " (" .. i .. ")"
                -- log("Imported copy " .. i) -- Reduce spam if needed, or keep for debug
            else
                log("Failed to import copy " .. i .. ": " .. tostring(res))
            end
        end
    else
        log("No duplicates needed (Tray full or part too big).")
    end
end

-- Main Execution Logic

if _G.netfabbtrayhandler then
    log("Using 'netfabbtrayhandler'. Tray Count: " .. netfabbtrayhandler.traycount)

    for i = 0, netfabbtrayhandler.traycount - 1 do
        local t = netfabbtrayhandler:gettray(i)
        if t then
            process_tray(t, "Tray " .. (i + 1))
        else
            log("Error: Failed to retrieve Tray " .. (i + 1))
        end
    end
else
    log("Error: 'netfabbtrayhandler' is not available.")
end

-- Update GUI
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

log("--- Script Complete ---")
