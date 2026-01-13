-- Diagnostics_Probe_CSV.lua
-- Exports Mesh Volume, Outbox Volume, Support Volume, and Estimated Build Time to CSV.
-- Probe v6: Checking getproperties(), getstate(), and System info.

-- Standard Logging Function
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- 1. Prompt for Directory Path
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

log("--- Starting Diagnostics Probe CSV v6 (Property Table Probe) ---")
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

-- Helper: Dump Table to Log
function log_table(tbl, prefix)
    if type(tbl) ~= "table" then return end
    for k, v in pairs(tbl) do
        log(prefix .. tostring(k) .. " = " .. tostring(v))
    end
end

-- Helper: Get Build Time with Property Table Probe
function get_build_time(tray)
    if not tray then return "nil" end

    log("  [Probing Build Time - v6]")

    -- 1. Test tray:getproperties()
    log("    Checking tray:getproperties()...")
    local props_func = nil
    pcall(function() props_func = tray.getproperties end)

    if props_func then
        local ok, res = pcall(function() return tray:getproperties() end)
        if ok and type(res) == "table" then
            log("      > SUCCESS: getproperties() returned a table.")
            log_table(res, "        [PROP] ")

            -- Check for build time in table
            if res.built_time_estimation_ms then return format_ms(res.built_time_estimation_ms) end
            if res.buildtime then return tostring(res.buildtime) end
            if res.time then return tostring(res.time) end
        else
            log("      > Call failed or returned non-table: " .. type(res))
        end
    else
         log("      > Method tray:getproperties not found.")
    end

    -- 2. Test tray:getstate()
    log("    Checking tray:getstate()...")
    local state_func = nil
    pcall(function() state_func = tray.getstate end)

    if state_func then
        local ok, res = pcall(function() return tray:getstate() end)
        if ok and res then
             log("      > SUCCESS: getstate() returned " .. type(res))
             if type(res) == "table" then log_table(res, "        [STATE] ") end
        end
    else
        log("      > Method tray:getstate not found.")
    end

    -- 3. System Level Checks (Run once generally, but safe here)
    if system.getjobinfo then
        log("    Checking system:getjobinfo()...")
        local ok, res = pcall(function() return system:getjobinfo() end)
        if ok and type(res) == "table" then
             log("      > SUCCESS: system:getjobinfo()")
             log_table(res, "        [JOB] ")
        end
    end

    -- Final fallback
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
