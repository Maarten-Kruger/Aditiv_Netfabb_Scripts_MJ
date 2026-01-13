-- Diagnostics_Probe_CSV.lua
-- Exports Mesh Volume, Outbox Volume, Support Volume, and Build Time (Placeholder) to CSV.
-- Final Clean Version: No Prompts, Build Time is "nil", Clean Output, Reordered Columns.
-- Modified by Jules: Added Filtering for "dup" names, Error Handling, and Popups.
-- EXTREMELY DETAILED LOGGING ADDED

-- Standard Logging Function
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Script Started: CSV Export with Detailed Logging ---")

-- 1. Prompt for Directory Path
local path_variable = ""

local ok_input, input_path = false, nil
local default_path = "C:\\"
local title = "Select Export Folder"

-- Try with 3 arguments (Title, DefaultPath, ShowNewFolderButton)
ok_input, input_path = pcall(function() return system:showdirectoryselectdialog(title, default_path, true) end)

-- Retry with 2 arguments if failed (API variation)
if not ok_input then
    ok_input, input_path = pcall(function() return system:showdirectoryselectdialog(title, default_path) end)
end

-- Fallback to system:inputdlg if still failed (Function missing or broken)
if not ok_input then
    ok_input, input_path = pcall(function() return system:inputdlg(title, title, default_path) end)
end

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
    log("User provided path: " .. path_variable)
else
    log("No directory selected or dialog cancelled. Exiting.")
    pcall(function() system:inputdlg("No directory selected. Script will exit.", "Error", "Error") end)
    return
end

-- 2. Correctly Format the Path
path_variable = string.gsub(path_variable, '"', '')
log("Sanitized path: " .. path_variable)

if path_variable == "" then
    log("Invalid path (empty after cleanup). Exiting.")
    pcall(function() system:inputdlg("Invalid path provided.", "Error", "Error") end)
    return
end

if string.sub(path_variable, -1) ~= "\\" then
    path_variable = path_variable .. "\\"
end

-- Setup Logging
local log_file_path = path_variable .. "csv_export_log.txt"
if system and system.logtofile then
    pcall(function() system:logtofile(log_file_path) end)
end

log("--- Script Started ---")
log("CSV Export Path: " .. path_variable)

local csv_file_name = "probe_volumes.csv"
local csv_path = path_variable .. csv_file_name
log("Target CSV path: " .. csv_path)

-- Main Execution Wrapper
local success_main, err_main = pcall(function()

    -- Helper: Safe Get Property
    local function safe_get(obj, key)
        local val = nil
        local ok, err = pcall(function() val = obj[key] end)
        if ok then
            -- log("safe_get: Successfully retrieved '" .. key .. "' (" .. tostring(val) .. ")")
            return val
        else
            log("safe_get: Failed to retrieve '" .. key .. "': " .. tostring(err))
            return nil
        end
    end

    -- Helper: Sanitize Name
    local function sanitize_name(name)
        if not name then return "Unknown" end
        -- Remove .stl extension (case insensitive)
        local clean = string.gsub(name, "%.[sS][tT][lL]$", "")
        return clean
    end

    -- Collect Data
    local csv_lines = {}
    -- Header: Build Time is LAST
    table.insert(csv_lines, "Tray Name,Mesh Name,Part Volume (Single),Total Part Volume,Bounding Box Volume,Support Volume (Single),Total Support Volume,Tray Build Time")

    local tray_handler = _G.netfabbtrayhandler
    local tray_count = 0
    if tray_handler then
        local ok_c, c = pcall(function() return tray_handler.traycount end)
        if ok_c then
            tray_count = c
            log("Tray handler found. Tray count: " .. tray_count)
        else
            log("Error getting tray count from handler: " .. tostring(c))
        end
    else
        log("Global 'netfabbtrayhandler' is nil.")
    end

    -- Default Build Time (User requested "nil" without prompts)
    local b_time = "nil"

    if tray_count > 0 then
        for t_i = 0, tray_count - 1 do
            log("Processing Tray Index: " .. t_i)
            local tray = tray_handler:gettray(t_i)

            -- Get Tray Name
            local tray_name = "Tray " .. t_i
            local t_name_val = safe_get(tray, "name")
            if t_name_val then
                tray_name = t_name_val
                log("Tray Name retrieved: " .. tray_name)
            else
                log("Using default tray name: " .. tray_name)
            end

            if tray and tray.root then
                log("Tray root mesh count: " .. tray.root.meshcount)
                for m_i = 0, tray.root.meshcount - 1 do
                    local mesh = tray.root:getmesh(m_i)
                    local raw_name = safe_get(mesh, "name")
                    log("Processing Mesh " .. m_i .. ": " .. tostring(raw_name))
                    local name = sanitize_name(raw_name)

                    -- FILTER: Skip if name contains "dup" (case insensitive)
                    if not string.find(string.lower(name), "dup") then

                        -- 1. Part Volume
                        local vol = safe_get(mesh, "volume") or 0
                        log("  Volume: " .. vol)

                        -- 2. Outbox Volume
                        local bb_vol = 0
                        local ob = safe_get(mesh, "outbox")
                        if ob then
                            local w = ob.maxx - ob.minx
                            local d = ob.maxy - ob.miny
                            local h = ob.maxz - ob.minz
                            bb_vol = w * d * h
                            log("  Outbox: " .. w .. " x " .. d .. " x " .. h .. " = " .. bb_vol)
                        else
                            log("  Outbox property missing or failed.")
                        end

                        -- 3. Support Volume
                        local sup_vol = 0
                        local sup = safe_get(mesh, "support")
                        if sup then
                            local sv = safe_get(sup, "volume")
                            if sv then
                                sup_vol = sv
                                log("  Support Volume: " .. sup_vol)
                            else
                                log("  Support object exists, but volume retrieval failed.")
                            end
                        else
                            log("  No support object found.")
                        end

                        -- 4. Calculate Totals (Assuming homogenous tray filled by duplicate_and_arrange)
                        local mesh_count = tray.root.meshcount
                        local total_part_vol = vol * mesh_count
                        local total_sup_vol = sup_vol * mesh_count
                        log("  Mesh Count in Tray: " .. mesh_count)
                        log("  Total Part Volume: " .. total_part_vol)
                        log("  Total Support Volume: " .. total_sup_vol)

                        -- Add Row (Build Time at End)
                        local row = string.format("%s,%s,%f,%f,%f,%f,%f,%s", tray_name, name, vol, total_part_vol, bb_vol, sup_vol, total_sup_vol, b_time)
                        table.insert(csv_lines, row)
                        log("  Added CSV Row: " .. row)
                    else
                        log("Skipping Duplicate Mesh (filtered): " .. name)
                    end
                end
            else
                log("Tray or Tray Root invalid for index " .. t_i)
            end
        end
    else
        -- Fallback: check _G.tray if no handler (or count 0)
        log("No trays in handler or count is 0. Checking _G.tray...")
        if _G.tray then
            local tray = _G.tray
            local tray_name = safe_get(tray, "name") or "Active Tray"
            log("Using Active Tray: " .. tray_name)

            if tray.root then
                log("Active Tray mesh count: " .. tray.root.meshcount)
                for m_i = 0, tray.root.meshcount - 1 do
                    local mesh = tray.root:getmesh(m_i)
                    local raw_name = safe_get(mesh, "name")
                    log("Processing Mesh " .. m_i .. ": " .. tostring(raw_name))
                    local name = sanitize_name(raw_name)

                     -- FILTER: Skip if name contains "dup"
                    if not string.find(string.lower(name), "dup") then
                        local vol = safe_get(mesh, "volume") or 0
                        log("  Volume: " .. vol)

                        local bb_vol = 0
                        local ob = safe_get(mesh, "outbox")
                        if ob then
                            local w = ob.maxx - ob.minx
                            local d = ob.maxy - ob.miny
                            local h = ob.maxz - ob.minz
                            bb_vol = w * d * h
                            log("  Outbox: " .. w .. " x " .. d .. " x " .. h .. " = " .. bb_vol)
                        else
                             log("  Outbox property missing.")
                        end

                        local sup_vol = 0
                        local sup = safe_get(mesh, "support")
                        if sup then
                            local sv = safe_get(sup, "volume")
                            if sv then
                                sup_vol = sv
                                log("  Support Volume: " .. sup_vol)
                            end
                        else
                             log("  No support object found.")
                        end

                        -- 4. Calculate Totals
                        local mesh_count = tray.root.meshcount
                        local total_part_vol = vol * mesh_count
                        local total_sup_vol = sup_vol * mesh_count
                        log("  Mesh Count in Tray: " .. mesh_count)
                        log("  Total Part Volume: " .. total_part_vol)
                        log("  Total Support Volume: " .. total_sup_vol)

                        local row = string.format("%s,%s,%f,%f,%f,%f,%f,%s", tray_name, name, vol, total_part_vol, bb_vol, sup_vol, total_sup_vol, b_time)
                        table.insert(csv_lines, row)
                        log("  Added CSV Row: " .. row)
                    else
                         log("Skipping Duplicate Mesh (filtered): " .. name)
                    end
                end
            end
        else
            log("No active tray (_G.tray) found.")
            table.insert(csv_lines, "No Trays Found,,,,,")
        end
    end

    -- Write to File
    log("Attempting to write CSV file...")
    -- Try io library first (CLEANEST OUTPUT)
    local io_ok, io_err = pcall(function()
        local file = io.open(csv_path, "w")
        if file then
            for _, line in ipairs(csv_lines) do
                file:write(line .. "\n")
            end
            file:close()
            return true
        else
            error("Could not open file")
        end
    end)

    if io_ok then
        log("CSV Exported successfully to: " .. csv_path)
    else
        -- Fallback to system:logtofile if io fails
        -- Note: This will include timestamps [YYYYMMDD...] which cannot be disabled.
        log("IO Library failed (" .. tostring(io_err) .. "). Using system log fallback (Timestamps will be present).")

        local ok_log, err_log = pcall(function() system:logtofile(csv_path) end)
        if ok_log then
            for _, line in ipairs(csv_lines) do
                if system and system.log then system:log(line) end
            end

            -- Attempt to close/detach log file
            pcall(function() system:logtofile("") end)
            log("Written via system:logtofile.")
        else
            log("Failed to write to file via system log: " .. tostring(err_log))
            error("Failed to write file via system log: " .. tostring(err_log))
        end
    end
end)

if success_main then
    log("Script finished successfully.")
    pcall(function() system:inputdlg("Export Complete", "Status", "Success") end)
else
    log("Critical Script Error: " .. tostring(err_main))
    pcall(function() system:inputdlg("Script Error: " .. tostring(err_main), "Error", "Error") end)
end
