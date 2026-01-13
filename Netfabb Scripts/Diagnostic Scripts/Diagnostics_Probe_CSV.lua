-- Diagnostics_Probe_CSV.lua
-- Exports Mesh Volume, Outbox Volume, Support Volume, and Estimated Build Time to CSV.
-- Now includes detailed probing for Build Time attributes and standard logging.

-- Standard Logging Function
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- 1. Prompt for Directory Path
-- This popup asks the user for a filepath (or directory path).
local path_variable = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Path to Save CSV & Log:", "Export Folder Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    log("No directory selected. Exiting.")
    return
end

-- 2. Correctly Format the Path
path_variable = string.gsub(path_variable, '"', '')

if path_variable == "" then
    log("Invalid path (empty after cleanup).")
    return
end

if string.sub(path_variable, -1) ~= "\\" then
    path_variable = path_variable .. "\\"
end

-- 3. Setup Files
local log_file_name = "probe_log.txt"
local log_file_path = path_variable .. log_file_name
local csv_file_name = "probe_volumes.csv"
local csv_path = path_variable .. csv_file_name

-- Setup Logging to File
if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if not ok then
        log("Failed to set log file: " .. tostring(err))
    else
        log("Log file set to: " .. log_file_path)
    end
end

log("--- Starting Diagnostics Probe CSV v2 ---")
log("CSV Target: " .. csv_path)

-- Helper: Safe Get Property
function safe_get(obj, key)
    local val = nil
    local ok, err = pcall(function() val = obj[key] end)
    if ok then return val else return nil end
end

-- Helper: Format Milliseconds to HH:MM:SS
function format_ms(ms)
    local seconds = math.floor(ms / 1000)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Helper: Get Build Time with Deep Probing
function get_build_time(tray)
    if not tray then return "nil" end

    log("  [Probing Build Time for Tray]")
    local val = nil
    local methods_tried = {}

    -- Attempt 1: getattribute('built_time_estimation_ms')
    -- This is the specific attribute mentioned in the Buildstyle documentation.
    local ok_1, res_1 = pcall(function() return tray:getattribute("built_time_estimation_ms") end)
    if ok_1 and res_1 then
        log("    > getattribute('built_time_estimation_ms') FOUND: " .. tostring(res_1))
        return format_ms(tonumber(res_1) or 0) .. " (Attrib)"
    else
        table.insert(methods_tried, "getattribute('built_time_estimation_ms')=" .. tostring(res_1))
    end

    -- Attempt 2: getproperty('built_time_estimation_ms')
    local ok_2, res_2 = pcall(function() return tray:getproperty("built_time_estimation_ms") end)
    if ok_2 and res_2 then
        log("    > getproperty('built_time_estimation_ms') FOUND: " .. tostring(res_2))
        return format_ms(tonumber(res_2) or 0) .. " (Prop)"
    else
        table.insert(methods_tried, "getproperty('built_time_estimation_ms')")
    end

    -- Attempt 3: Direct property access .built_time_estimation_ms
    local ok_3, res_3 = pcall(function() return tray.built_time_estimation_ms end)
    if ok_3 and res_3 then
        log("    > tray.built_time_estimation_ms FOUND: " .. tostring(res_3))
        return format_ms(tonumber(res_3) or 0) .. " (Direct)"
    else
        table.insert(methods_tried, "tray.built_time_estimation_ms")
    end

    -- Attempt 4: Generic 'buildtime' property (sometimes exists on system/slice)
    local ok_4, res_4 = pcall(function() return tray.buildtime end)
    if ok_4 and res_4 then
        log("    > tray.buildtime FOUND: " .. tostring(res_4))
        return tostring(res_4)
    end

    -- Attempt 5: Legacy Slice Object Check
    local slice = safe_get(tray, "slice")
    if slice then
         local bt = safe_get(slice, "buildtime")
         if bt then
            log("    > tray.slice.buildtime FOUND: " .. tostring(bt))
            return tostring(bt)
         end
    end

    log("    > All attempts failed: " .. table.concat(methods_tried, ", "))
    return "nil"
end


-- Collect Data
local results = {}
table.insert(results, "Tray Name,Tray Build Time,Mesh Name,Part Volume,Bounding Box Volume,Support Volume")

local tray_handler = _G.netfabbtrayhandler
local tray_count = 0
if tray_handler then
    local ok_c, c = pcall(function() return tray_handler.traycount end)
    if ok_c then tray_count = c end
end

log("Tray Count: " .. tray_count)

if tray_count > 0 then
    for t_i = 0, tray_count - 1 do
        local tray = tray_handler:gettray(t_i)

        -- Get Tray Name
        local tray_name = "Tray " .. t_i
        local t_name_val = safe_get(tray, "name")
        if t_name_val then tray_name = t_name_val end

        -- Get Build Time
        local b_time = get_build_time(tray)

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

                table.insert(results, string.format("%s,%s,%s,%f,%f,%f", tray_name, b_time, name, vol, bb_vol, sup_vol))
            end
        end
    end
else
    -- Fallback: check _G.tray if no handler (or count 0)
    if _G.tray then
        local tray = _G.tray
        local tray_name = safe_get(tray, "name") or "Active Tray"

        -- Get Build Time
        local b_time = get_build_time(tray)

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
                table.insert(results, string.format("%s,%s,%s,%f,%f,%f", tray_name, b_time, name, vol, bb_vol, sup_vol))
            end
        end
    else
        table.insert(results, "No Trays Found,,,,,")
    end
end

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
    log("CSV Exported successfully to: " .. csv_path)
else
    -- Fallback to system:logtofile if io fails
    log("IO Library failed (" .. tostring(io_err) .. "). using system:logtofile (Will include timestamps in CSV)")

    -- We can't easily write a clean CSV without timestamps using system:logtofile,
    -- but we will dump the data there so it's saved.
    pcall(function() system:logtofile(csv_path) end)
    for _, line in ipairs(results) do
        if system and system.log then system:log(line) end
    end
    log("CSV Logged to: " .. csv_path)
end

log("--- Script Complete ---")
