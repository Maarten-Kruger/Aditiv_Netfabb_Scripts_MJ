-- Diagnostics_Probe_CSV.lua
-- Exports Mesh Volume, Outbox Volume, Support Volume, and Estimated Build Time to CSV.
-- Probe v4: Targeting PDF-specific method names for attribute retrieval.

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

log("--- Starting Diagnostics Probe CSV v4 (Targeted Method Probe) ---")
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

-- Helper: Get Build Time with Targeted Probing
function get_build_time(tray)
    if not tray then return "nil" end

    log("  [Probing Build Time]")
    local val = nil
    local methods_tried = {}

    -- LIST OF CANDIDATE METHODS TO TRY
    -- Derived from PDF: "a_modelData.getTrayAttribEx" and "a_modelData.getTrayAttrib"
    local candidates = {
        {name="getTrayAttrib", args={"built_time_estimation_ms"}},
        {name="gettrayattrib", args={"built_time_estimation_ms"}},
        {name="getTrayAttribEx", args={"built_time_estimation_ms"}},
        {name="gettrayattribex", args={"built_time_estimation_ms"}},
        {name="getAttrib", args={"built_time_estimation_ms"}},
        {name="getattrib", args={"built_time_estimation_ms"}},
        {name="getattribute", args={"built_time_estimation_ms"}}, -- Retrying just in case
        {name="getproperty", args={"built_time_estimation_ms"}},
        {name="getparameter", args={"built_time_estimation_ms"}},
        {name="getmachineparameter", args={"built_time_estimation_ms"}},
        {name="getsetting", args={"built_time_estimation_ms"}}
    }

    for _, method in ipairs(candidates) do
        local func_name = method.name
        local arg = method.args[1]

        -- Check if function exists on object first
        local func = nil
        local ok_idx, err_idx = pcall(function() func = tray[func_name] end)

        if ok_idx and func and type(func) == "function" then
            log("    Function FOUND: tray:" .. func_name)
            -- Call it
            local ok_call, res = pcall(function() return tray[func_name](tray, arg) end)
            if ok_call and res then
                log("      > SUCCESS: " .. func_name .. " returned " .. tostring(res))
                return format_ms(tonumber(res) or 0) .. " (" .. func_name .. ")"
            else
                log("      > Call failed or returned nil: " .. tostring(res))
            end
        else
            -- Uncomment below for verbose fail logs
            -- log("    Method missing: " .. func_name)
        end
    end

    -- Last Resort: Check specific property keys again
    if tray.built_time_estimation_ms then return format_ms(tray.built_time_estimation_ms) end
    if tray.buildtime then return tostring(tray.buildtime) end

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
