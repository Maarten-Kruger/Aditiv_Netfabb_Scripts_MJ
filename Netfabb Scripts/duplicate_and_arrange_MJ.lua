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

    -- Sanitize names for filename and usage
    local raw_name = template_part.name
    -- Remove .stl extension (case insensitive)
    local name_no_ext = string.gsub(raw_name, "%.[sS][tT][lL]$", "")
    -- Remove non-alphanumeric characters
    local safe_part = string.gsub(name_no_ext, "[^%w%-_]", "")

    -- 2.5 Export 3MF of the Template Part (Backup)
    log("Exporting Backup 3MF for " .. template_part.name .. "...")
    local exp_ok, exp_err = pcall(function()
        if system and system.create3mfexporter then
            local exporter = system:create3mfexporter()
            local entry = exporter:add(template_part.mesh)
            entry.name = template_part.name
            entry.grouppath = "3mfexport/parts"

            if template_part.hassupport then
                entry:setsupport(template_part.support)
            end

            -- New Filename Format: [safe_part]_3mf.3mf
            local export_filename = save_path .. safe_part .. "_3mf.3mf"

            exporter:exporttofile(export_filename)
            log("Exported backup to: " .. export_filename)
        else
            log("Warning: system:create3mfexporter not available.")
        end
    end)

    if not exp_ok then
        log("Export Failed: " .. tostring(exp_err))
    end

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

    -- 6. Duplicate the part via Export-Import Loop
    if duplicates_needed > 0 then
        log("Starting Export-Import Duplication Loop...")
        update_progress(20, "Processing " .. tray_name .. ": Duplicating " .. duplicates_needed .. " parts...")

        -- Step A: Create "Non-Editable" Split Export
        local temp_3mf_path = save_path .. safe_part .. "_noneditable.3mf"
        local split_export_ok, split_msg = pcall(function()
            local part_geo = nil
            local supp_geo = nil

            -- Extract Part
            local ok_p, res_p = pcall(function() return template_part:createsupportedmesh(true, false, false, 0.0) end)
            if ok_p and res_p then part_geo = res_p.mesh end

            -- Extract Support
            local ok_s, res_s = pcall(function() return template_part:createsupportedmesh(false, true, true, 0.0) end)
            if ok_s and res_s then supp_geo = res_s.mesh end

            if not part_geo then error("Failed to extract part geometry") end

            local exporter = system:create3mfexporter()

            -- Add Part Entry
            local p_entry = exporter:add(part_geo)
            p_entry.name = safe_part
            p_entry.grouppath = "Production/Parts"

            -- Add Support Entry (if exists)
            if supp_geo then
                local s_entry = exporter:add(supp_geo)
                s_entry.name = safe_part .. "_Support"
                s_entry.grouppath = "Production/Supports"
            end

            exporter:exporttofile(temp_3mf_path)
        end)

        if not split_export_ok then
            log("Error creating temp split export: " .. tostring(split_msg))
            -- Abort duplication if export failed
            duplicates_needed = 0
        else
            log("Temp split export created at: " .. temp_3mf_path)

            -- Step B: Import Loop
            for i = 1, duplicates_needed do
                local imp_ok, imp_res = pcall(function()
                    -- Import with split_meshes=true
                    local importer = system:create3mfimporter(temp_3mf_path, true, "ImportGroup", current_tray)
                    if not importer then return "Importer creation failed" end

                    local imp_part = nil
                    local imp_supp = nil

                    -- Iterate meshes from importer
                    for m_idx = 0, importer.meshcount - 1 do
                        local m = importer:getmesh(m_idx)
                        local m_name = "Unknown"
                        pcall(function() m_name = importer:getname(m_idx) end)

                        -- Add to tray
                        local tm = root:addmesh(m)

                        -- Identify
                        -- Matches exported names: safe_part and safe_part .. "_Support"
                        -- Importer might change names slightly (e.g. invalid chars), but safe_part is already safe.
                        -- Checks:
                        if string.find(m_name, "_Support") then
                            imp_supp = tm
                        else
                            -- Assume part if not support (and we only exported two things)
                            imp_part = tm
                        end
                    end

                    -- Re-assign Support
                    if imp_part and imp_supp then
                        imp_part:assignsupport(imp_supp, false) -- false = absolute coords
                        root:removemesh(imp_supp)
                    end

                    -- Rename
                    if imp_part then
                        imp_part.name = safe_part .. "_dup" .. i
                    end
                end)

                if not imp_ok then
                    log("Error in duplication loop " .. i .. ": " .. tostring(imp_res))
                end

                -- Update Progress
                 if i % 5 == 0 then
                     local pct = 20 + (i / duplicates_needed) * 60 -- 20% to 80%
                     update_progress(pct, "Processing " .. tray_name .. ": Imported " .. i .. "/" .. duplicates_needed)
                 end
            end

            log("Duplication loop complete.")

            -- Step C: Cleanup Temp File
            pcall(function()
                if os and os.remove then
                    os.remove(temp_3mf_path)
                    log("Temp file deleted.")
                else
                    log("Could not delete temp file (os.remove unavailable).")
                end
            end)
        end
    else
        log("No duplicates needed.")
    end

    -- 8. Pack the Tray
    log("Arranging parts in " .. tray_name .. "...")
    update_progress(90, "Processing " .. tray_name .. ": Packing...")

    if current_tray.createpacker then
        local p_ok, packer = pcall(function() return current_tray:createpacker(current_tray.packingid_2d) end)
        if p_ok and packer then
            -- Configure Packer Settings based on Pack_Trays_Scanline_MJ.lua
            local cfg_ok, cfg_err = pcall(function()
                packer.rastersize = 1       -- Voxel size (mm)
                packer.anglecount = 7       -- Rotation steps
                packer.coarsening = 1       -- Accuracy
                packer.placeoutside = true  -- Allow placing remaining parts outside
                packer.borderspacingxy = 1.0 -- Spacing between parts/border
                packer.packonlyselected = false -- Pack all parts
            end)

            if cfg_ok then
                 local pack_ok, pack_res = pcall(function() return packer:pack() end)
                 if pack_ok then
                     log("Packing complete (Code: " .. tostring(pack_res) .. ").")
                 else
                     log("Packing failed/crashed: " .. tostring(pack_res))
                 end
            else
                 log("Failed to configure packer: " .. tostring(cfg_err))
            end
        else
            log("Failed to create Scanline (packingid_2d) packer.")
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
