-- Diagnostics_Probe_CSV.lua
-- Exports Mesh Volume, Outbox Volume, and Support Volume to CSV for ALL Trays.
-- prompts user for Build Time and Layer Height for each tray.

-- 1. Prompt for Directory Path
local path_variable = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Path to Save CSV File:", "Export Folder Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    path_variable = "C:\\"
end

path_variable = string.gsub(path_variable, '"', '')
if string.sub(path_variable, -1) ~= "\\" then
    path_variable = path_variable .. "\\"
end

local csv_file_name = "probe_volumes.csv"
local csv_path = path_variable .. csv_file_name

-- Function to safely get property
function safe_get(obj, key)
    local val = nil
    local ok, err = pcall(function() val = obj[key] end)
    if ok then return val else return nil end
end

-- Collect Data
local results = {}
table.insert(results, "Tray Name,Mesh Name,Part Volume,Bounding Box Volume,Support Volume,Build Time,Layer Height")

local tray_handler = _G.netfabbtrayhandler
local tray_count = 0
if tray_handler then
    local ok_c, c = pcall(function() return tray_handler.traycount end)
    if ok_c then tray_count = c end
end

if tray_count > 0 then
    for t_i = 0, tray_count - 1 do
        local tray = tray_handler:gettray(t_i)

        -- Get Tray Name
        local tray_name = "Tray " .. t_i
        local t_name_val = safe_get(tray, "name")
        if t_name_val then tray_name = t_name_val end

        -- Prompt User for Manual Data
        local manual_data = ""
        local ok_dlg, input_data = pcall(function()
            return system:inputdlg("Enter 'Build Time, Layer Height' for " .. tray_name, "Manual Data Input (" .. (t_i+1) .. "/" .. tray_count .. ")", "0, 0")
        end)

        local build_time = "0"
        local layer_height = "0"

        if ok_dlg and input_data then
            -- Simple parse by comma
            local p1, p2 = string.match(input_data, "([^,]+),([^,]+)")
            if p1 then build_time = p1 end
            if p2 then layer_height = p2 end

            -- Trim whitespace
            build_time = string.gsub(build_time, "^%s*(.-)%s*$", "%1")
            layer_height = string.gsub(layer_height, "^%s*(.-)%s*$", "%1")
        end

        if tray and tray.root then
            for m_i = 0, tray.root.meshcount - 1 do
                local mesh = tray.root:getmesh(m_i)
                local name = safe_get(mesh, "name") or "Unknown"

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

                table.insert(results, string.format("%s,%s,%f,%f,%f,%s,%s", tray_name, name, vol, bb_vol, sup_vol, build_time, layer_height))
            end
        end
    end
else
    -- Fallback: check _G.tray if no handler (or count 0)
    if _G.tray then
        local tray = _G.tray
        local tray_name = safe_get(tray, "name") or "Active Tray"

        -- Prompt User for Manual Data
        local manual_data = ""
        local ok_dlg, input_data = pcall(function()
            return system:inputdlg("Enter 'Build Time, Layer Height' for " .. tray_name, "Manual Data Input", "0, 0")
        end)

        local build_time = "0"
        local layer_height = "0"

        if ok_dlg and input_data then
            local p1, p2 = string.match(input_data, "([^,]+),([^,]+)")
            if p1 then build_time = p1 end
            if p2 then layer_height = p2 end
            build_time = string.gsub(build_time, "^%s*(.-)%s*$", "%1")
            layer_height = string.gsub(layer_height, "^%s*(.-)%s*$", "%1")
        end

        if tray.root then
            for m_i = 0, tray.root.meshcount - 1 do
                local mesh = tray.root:getmesh(m_i)
                local name = safe_get(mesh, "name") or "Unknown"
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
                table.insert(results, string.format("%s,%s,%f,%f,%f,%s,%s", tray_name, name, vol, bb_vol, sup_vol, build_time, layer_height))
            end
        end
    else
        table.insert(results, "No Trays Found,,,,,,")
    end
end

-- Final Confirmation
local ok_confirm, confirm_input = pcall(function()
    return system:inputdlg("Data collection complete. Type 'yes' to save the CSV file.", "Confirm Export", "yes")
end)

if ok_confirm and confirm_input and string.lower(confirm_input) == "yes" then
    -- Write to File
    -- Try io library first
    local io_ok, io_err = pcall(function()
        local file = io.open(csv_path, "w")
        if file then
            for _, line in ipairs(results) do
                file:write(line .. "\n")
            end
            file:close()
            return true
        else
            error("Could not open file")
        end
    end)

    if io_ok then
        if system and system.log then system:log("CSV Exported successfully to: " .. csv_path) end
    else
        -- Fallback to system:logtofile if io fails
        if system and system.log then system:log("IO Library failed (" .. tostring(io_err) .. "). using system:logtofile (Will include timestamps)") end
        if system and system.logtofile then
            pcall(function() system:logtofile(csv_path) end)
            for _, line in ipairs(results) do
                if system and system.log then system:log(line) end
            end
            if system and system.log then system:log("CSV Logged (with timestamps) to: " .. csv_path) end
        end
    end
else
    if system and system.log then system:log("Export cancelled by user.") end
end
