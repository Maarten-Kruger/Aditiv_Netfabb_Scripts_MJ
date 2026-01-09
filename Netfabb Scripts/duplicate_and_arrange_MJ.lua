-- duplicate_and_arrange_MJ.lua
-- Duplicates a part in every tray to fill the tray.
-- Modified by Jules

local tray_percentage = 0.6 -- Percentage of tray area to fill (0.0 to 1.0)
local is_cylinder = true   -- Set to true if the build platform is cylindrical
local save_path = "C:\\Users\\Maarten\\OneDrive\\Desktop" -- Default Save Path

-- 1. Popup for Filepath
if system and system.showdirectoryselectdialog then
    local selected = system:showdirectoryselectdialog("Select Save Folder", save_path, true)
    if selected and selected ~= "" then
        save_path = selected
    end
end

-- Sanitize path (remove quotes if present)
save_path = string.gsub(save_path, '"', '')
-- Ensure no trailing slash for consistency (we add it later)
if string.sub(save_path, -1) == "\\" then
    save_path = string.sub(save_path, 1, -2)
end

local log_file_path = save_path .. "\\duplicate_log.txt"

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
log("Save Path: " .. save_path)
log("Log file location: " .. log_file_path)

-- Function to process a single tray
local function process_tray(current_tray, tray_name)
    log("--- Processing " .. tray_name .. " ---")

    if not current_tray or not current_tray.root then
        log("Error: Tray root not available for " .. tray_name)
        return
    end

    local root = current_tray.root

    -- 2. Cleanup / Overwrite Logic
    -- Keep the first mesh (index 0) as template, delete others.
    if root.meshcount > 1 then
        log("Cleaning up existing duplicates...")
        local to_remove = {}
        -- Iterate backwards to avoid index shifting issues, but safer to collect first
        for i = 1, root.meshcount - 1 do
            table.insert(to_remove, root:getmesh(i))
        end
        for _, m in ipairs(to_remove) do
            root:removemesh(m)
        end
        log("Removed " .. #to_remove .. " existing parts.")
    end

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

    -- 3. Calculate Part Area
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

    -- 4. Calculate Tray Area
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

    -- 5. Calculate Max Parts
    local target_fill_area = tray_area * tray_percentage
    local max_count = math.floor(target_fill_area / part_area)
    local duplicates_needed = max_count - 1

    log("Target Fill Area: " .. target_fill_area .. " (" .. (tray_percentage * 100) .. "%)")
    log("Max Parts: " .. max_count)
    log("Duplicates Needed: " .. duplicates_needed)

    -- 6. Duplicate the part (using createsupportedmesh to preserve supports)
    if duplicates_needed > 0 then
        log("Duplicating part via createsupportedmesh...")

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

        -- Generate Master Geometry with baked supports
        -- createsupportedmesh(mergepart, mergeopensupport, mergeclosedsupport, openthickening)
        local master_geometry = nil
        if template_part.createsupportedmesh then
            local success_sup, res_sup = pcall(function()
                return template_part:createsupportedmesh(true, true, true, 0.0)
            end)

            if success_sup and res_sup then
                -- Check for mesh property safely
                local has_mesh_prop = false
                pcall(function()
                    if res_sup.mesh then has_mesh_prop = true end
                end)

                if has_mesh_prop then
                     master_geometry = res_sup.mesh
                     log("Successfully generated supported mesh geometry (TrayMesh).")
                else
                     -- Maybe it IS a LuaMesh?
                     local is_luamesh = false
                     pcall(function() if res_sup.facecount then is_luamesh = true end end)

                     if is_luamesh then
                         master_geometry = res_sup
                         log("Successfully generated supported mesh geometry (LuaMesh).")
                     else
                         log("Error: createsupportedmesh returned unknown object type.")
                     end
                end
            else
                log("Error: createsupportedmesh call failed: " .. tostring(res_sup))
            end
        else
            log("Error: createsupportedmesh method not available on this version.")
        end

        if master_geometry then
             -- Add copies
             local newly_added = {}
             for i = 1, duplicates_needed do
                 -- Add the mesh to the tray
                 local new_traymesh = root:addmesh(master_geometry)
                 new_traymesh.name = base_name .. " (" .. i .. ")"
                 table.insert(newly_added, new_traymesh)
             end
             log("Added " .. duplicates_needed .. " supported duplicates.")

             -- 7. Full Repair on Duplicates
             log("Running full-on repair (repairextended) on duplicates...")
             for i, m in ipairs(newly_added) do
                 local m_name = m.name
                 local m_mesh = m.mesh -- The LuaMesh
                 if m_mesh then
                     local copy_mesh = m_mesh:dupe()
                     copy_mesh:repairextended()

                     -- Replace in tray
                     root:removemesh(m)
                     local repaired_tm = root:addmesh(copy_mesh)
                     repaired_tm.name = m_name
                 end
                 -- Progress logging
                 if i % 10 == 0 then log("Repaired " .. i .. "/" .. #newly_added) end
             end
             log("Repair complete.")

        else
             log("Aborting duplication due to failure in generating master mesh.")
        end

    else
        log("No duplicates needed (Tray full or part too big).")
    end

    -- 8. Export 3MF
    -- Try to save the tray or parts
    local export_file = save_path .. "\\" .. tray_name .. ".3mf"
    log("Attempting export to: " .. export_file)

    local exported = false
    -- Attempt 1: Check if tray has a save method (unlikely but possible)
    if current_tray.saveto3mf then
        local ok, err = pcall(function() current_tray:saveto3mf(export_file) end)
        if ok then
            log("Export successful via tray:saveto3mf")
            exported = true
        else
            log("tray:saveto3mf failed: " .. tostring(err))
        end
    end

    if not exported then
        -- Attempt 2: Iterate parts and save individually if we can't save the tray
        -- Or save the template part if it's the only type? No, we have duplicates.
        -- If we can't save the whole tray, we save parts into a folder.
        log("Tray export method not found. Saving individual parts...")

        local tray_dir = save_path .. "\\" .. tray_name .. "_Parts"
        if system.createdirectory then system:createdirectory(tray_dir) end

        -- Export all meshes in tray
        for i = 0, root.meshcount - 1 do
            local tm = root:getmesh(i)
            local part_path = tray_dir .. "\\" .. tm.name .. ".3mf"
            local lm = tm.mesh
            local ok, err = pcall(function() lm:saveto3mf(part_path) end)
            if not ok then
                 log("Failed to export " .. tm.name .. ": " .. tostring(err))
            end
        end
        log("Parts exported to " .. tray_dir)
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
