-- Diagnostics_Probe_CSV.lua
-- Exports Mesh Volume, Outbox Volume, Support Volume, and Build Time (Placeholder) to CSV.
-- Final Clean Version: No Prompts, Build Time is "nil", Clean Output, Reordered Columns.
-- Modified by Jules: Added Filtering for "dup" names, Error Handling, and Popups.

-- Standard Logging Function
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- 1. Prompt for Directory Path
local path_variable = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Path to Save CSV:", "Export Folder Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    log("No directory selected. Exiting.")
    return
end

-- 2. Correctly Format the Path
path_variable = string.gsub(path_variable, '"', '')

if path_variable == "" then
    log("Invalid path. Exiting.")
    return
end

if string.sub(path_variable, -1) ~= "\\" then
    path_variable = path_variable .. "\\"
end

local csv_file_name = "probe_volumes.csv"
local csv_path = path_variable .. csv_file_name

-- Main Execution Wrapper
local success_main, err_main = pcall(function()

    -- Helper: Safe Get Property
    local function safe_get(obj, key)
        local val = nil
        local ok, err = pcall(function() val = obj[key] end)
        if ok then return val else return nil end
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
    table.insert(csv_lines, "Tray Name,Mesh Name,Part Volume,Bounding Box Volume,Support Volume,Tray Build Time")

    local tray_handler = _G.netfabbtrayhandler
    local tray_count = 0
    if tray_handler then
        local ok_c, c = pcall(function() return tray_handler.traycount end)
        if ok_c then tray_count = c end
    end

    -- Default Build Time (User requested "nil" without prompts)
    local b_time = "nil"

    if tray_count > 0 then
        for t_i = 0, tray_count - 1 do
            local tray = tray_handler:gettray(t_i)

            -- Get Tray Name
            local tray_name = "Tray " .. t_i
            local t_name_val = safe_get(tray, "name")
            if t_name_val then tray_name = t_name_val end

            if tray and tray.root then
                for m_i = 0, tray.root.meshcount - 1 do
                    local mesh = tray.root:getmesh(m_i)
                    local raw_name = safe_get(mesh, "name")
                    local name = sanitize_name(raw_name)

                    -- FILTER: Skip if name contains "dup" (case insensitive)
                    if not string.find(string.lower(name), "dup") then

                        -- 1. Part Volume
                        local vol = safe_get(mesh, "volume") or 0

                        -- 2. Outbox Volume
                        local bb_vol = 0
                        local ob = safe_get(mesh, "outbox")
                        if ob then
                            local w = ob.maxx - ob.minx
                            local d = ob.maxy - ob.miny
                            local h = ob.maxz - ob.minz
                            bb_vol = w * d * h
                        end

                        -- 3. Support Volume
                        local sup_vol = 0
                        local sup = safe_get(mesh, "support")
                        if sup then
                            local sv = safe_get(sup, "volume")
                            if sv then sup_vol = sv end
                        end

                        -- Add Row (Build Time at End)
                        table.insert(csv_lines, string.format("%s,%s,%f,%f,%f,%s", tray_name, name, vol, bb_vol, sup_vol, b_time))
                    else
                        log("Skipping Duplicate Mesh: " .. name)
                    end
                end
            end
        end
    else
        -- Fallback: check _G.tray if no handler (or count 0)
        if _G.tray then
            local tray = _G.tray
            local tray_name = safe_get(tray, "name") or "Active Tray"

            if tray.root then
                for m_i = 0, tray.root.meshcount - 1 do
                    local mesh = tray.root:getmesh(m_i)
                    local raw_name = safe_get(mesh, "name")
                    local name = sanitize_name(raw_name)

                     -- FILTER: Skip if name contains "dup"
                    if not string.find(string.lower(name), "dup") then
                        local vol = safe_get(mesh, "volume") or 0
                        local bb_vol = 0
                        local ob = safe_get(mesh, "outbox")
                        if ob then
                            local w = ob.maxx - ob.minx
                            local d = ob.maxy - ob.miny
                            local h = ob.maxz - ob.minz
                            bb_vol = w * d * h
                        end
                        local sup_vol = 0
                        local sup = safe_get(mesh, "support")
                        if sup then
                            local sv = safe_get(sup, "volume")
                            if sv then sup_vol = sv end
                        end
                        table.insert(csv_lines, string.format("%s,%s,%f,%f,%f,%s", tray_name, name, vol, bb_vol, sup_vol, b_time))
                    else
                         log("Skipping Duplicate Mesh: " .. name)
                    end
                end
            end
        else
            table.insert(csv_lines, "No Trays Found,,,,,")
        end
    end

    -- Write to File
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
        log("IO Library failed. Using system log fallback (Timestamps will be present).")

        local ok_log, err_log = pcall(function() system:logtofile(csv_path) end)
        if ok_log then
            for _, line in ipairs(csv_lines) do
                if system and system.log then system:log(line) end
            end

            -- Attempt to close/detach log file
            pcall(function() system:logtofile("") end)
        else
            log("Failed to write to file via system log: " .. tostring(err_log))
            error("Failed to write file via system log: " .. tostring(err_log))
        end
    end
end)

if success_main then
    pcall(function() system:inputdlg("Export Complete", "Status", "Success") end)
else
    log("Critical Script Error: " .. tostring(err_main))
    pcall(function() system:inputdlg("Script Error", "Error", tostring(err_main)) end)
end
