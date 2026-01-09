-- duplicate_and_arrange_MJ.lua
-- Duplicates a part in every tray to fill the tray and arranges them.
-- Modified by Jules

local tray_percentage = 0.6 -- Percentage of tray area to fill (0.0 to 1.0)
local is_cylinder = true   -- Set to true if the build platform is cylindrical
local save_path = ""

-- 1. Popup for Filepath
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Directory Path to Save Log File to:", "Import Log Folder Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    save_path = input_path
else
    -- Fallback or exit?
    if system and system.log then system:log("No directory selected. Exiting.") end
    return
end

-- Sanitize path (remove quotes if present)
save_path = string.gsub(save_path, '"', '')

if save_path == "" then
     if system and system.log then system:log("Invalid path (empty after cleanup).") end
     return
end

-- Ensure trailing backslash
if string.sub(save_path, -1) ~= "\\" then
    save_path = save_path .. "\\"
end

local log_file_path = save_path .. "duplicate_log.txt"

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
    print(msg)
end

log("--- Script Started ---")
log("Save Path: " .. save_path)
log("Log file location: " .. log_file_path)

-- Initialize Progress Bar
if system and system.showprogressdlgcancancel then
    system:showprogressdlgcancancel(true)
end

local function update_progress(percent, message)
    if system and system.setprogresscancancel then
        system:setprogresscancancel(percent, message, false)
        if system:progresscancelled() then
            log("Script cancelled by user.")
            error("Cancelled")
        end
    end
end

-- Function to process a single tray
local function process_tray(current_tray, tray_name)
    log("--- Processing " .. tray_name .. " ---")
    update_progress(0, "Processing " .. tray_name .. ": Analyzing...")

    if not current_tray or not current_tray.root then
        log("Error: Tray root not available for " .. tray_name)
        return
    end

    local root = current_tray.root

    -- 2. Cleanup / Overwrite Logic
    -- Keep the first mesh (index 0) as template, delete others.
    if root.meshcount > 1 then
        log("Cleaning up existing duplicates...")
        update_progress(10, "Processing " .. tray_name .. ": Cleaning up...")
        local to_remove = {}
        for i = 1, root.meshcount - 1 do
            table.insert(to_remove, root:getmesh(i))
        end
        for _, m in ipairs(to_remove) do
            root:removemesh(m)
        end
        log("Removed " .. #to_remove .. " existing parts.")
    end

    -- 1. Find a template part
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

    local success, area = pcall(function() return luamesh:outboxbasearea() end)
    if success and area and area > 0 then
        part_area = area
        log("Part Area (from outboxbasearea): " .. part_area)
    else
        local ob = nil
        pcall(function() ob = template_part.outbox end)
        if ob then
            local width = ob.maxx - ob.minx
            local depth = ob.maxy - ob.miny
            part_area = width * depth
            log("Part Area (calculated from outbox): " .. part_area)
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

    if is_cylinder then
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

    -- 6. Duplicate the part
    if duplicates_needed > 0 then
        log("Duplicating part via createsupportedmesh...")
        update_progress(20, "Processing " .. tray_name .. ": Duplicating " .. duplicates_needed .. " parts...")

        local base_name = template_part.name
        base_name = string.gsub(base_name, "%s*%(%d+%)", "")
        base_name = string.gsub(base_name, "_copy", "")
        base_name = string.gsub(base_name, "%.%w+$", "")
        base_name = string.gsub(base_name, "%s+$", "")

        local master_geometry = nil
        if template_part.createsupportedmesh then
            local success_sup, res_sup = pcall(function()
                return template_part:createsupportedmesh(true, true, true, 0.0)
            end)

            if success_sup and res_sup then
                local has_mesh_prop = false
                pcall(function() if res_sup.mesh then has_mesh_prop = true end end)

                if has_mesh_prop then
                     master_geometry = res_sup.mesh
                else
                     local is_luamesh = false
                     pcall(function() if res_sup.facecount then is_luamesh = true end end)
                     if is_luamesh then master_geometry = res_sup end
                end
            end
        end

        if master_geometry then
             local newly_added = {}
             for i = 1, duplicates_needed do
                 local new_traymesh = root:addmesh(master_geometry)
                 new_traymesh.name = base_name .. "_(dupe_" .. i .. ")"
                 table.insert(newly_added, new_traymesh)
             end
             log("Added " .. duplicates_needed .. " supported duplicates.")

             -- 7. Full Repair on Duplicates
             log("Running repair (repairextended) on duplicates...")
             update_progress(50, "Processing " .. tray_name .. ": Repairing duplicates...")

             for i, m in ipairs(newly_added) do
                 local m_name = m.name
                 local m_mesh = m.mesh
                 if m_mesh then
                     local copy_mesh = m_mesh:dupe()
                     copy_mesh:repairextended()
                     root:removemesh(m)
                     local repaired_tm = root:addmesh(copy_mesh)
                     repaired_tm.name = m_name
                 end
                 -- Sub-progress
                 if i % 5 == 0 then
                     local pct = 50 + (i / #newly_added) * 30 -- 50% to 80%
                     update_progress(pct, "Processing " .. tray_name .. ": Repairing part " .. i .. "/" .. #newly_added)
                 end
             end
             log("Repair complete.")
        else
             log("Aborting duplication due to failure in generating master mesh.")
        end
    else
        log("No duplicates needed.")
    end

    -- 8. Pack the Tray
    log("Arranging parts in " .. tray_name .. "...")
    update_progress(90, "Processing " .. tray_name .. ": Packing...")

    if current_tray.createpacker then
        local p_ok, packer = pcall(function() return current_tray:createpacker(current_tray.packingid_trueshape) end)
        if p_ok and packer then
            packer.packing_2d = true
            packer.minimaldistance = 2.0

            local pack_ok, pack_res = pcall(function() return packer:pack() end)
            if pack_ok then
                log("Packing complete.")
            else
                log("Packing failed: " .. tostring(pack_res))
            end
        else
            log("Failed to create TrueShape packer.")
        end
    else
        log("createpacker method not available.")
    end

end

-- Main Execution Logic
local success_main, err_main = pcall(function()
    if _G.netfabbtrayhandler then
        log("Using 'netfabbtrayhandler'. Tray Count: " .. netfabbtrayhandler.traycount)

        local count = netfabbtrayhandler.traycount
        for i = 0, count - 1 do
            local t = netfabbtrayhandler:gettray(i)
            if t then
                process_tray(t, "Tray " .. (i + 1))
            else
                log("Error: Failed to retrieve Tray " .. (i + 1))
            end

            -- Update global progress implicitly by the loop, or explicit reset
            update_progress((i + 1) / count * 100, "Completed Tray " .. (i + 1))
        end
    else
        log("Error: 'netfabbtrayhandler' is not available.")
    end
end)

if not success_main then
    log("Script Error: " .. tostring(err_main))
    -- If cancelled, we already logged it, but this catches other errors
end

-- Cleanup Progress Bar
if system and system.hideprogressdlgcancancel then
    system:hideprogressdlgcancancel()
end

-- Update GUI
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

log("--- Script Complete ---")
