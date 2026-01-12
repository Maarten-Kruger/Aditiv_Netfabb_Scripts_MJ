-- Export_Build_Data_CSV.lua
-- Exports build data to a CSV, consolidating info from an existing CSV and the Netfabb environment.
-- Updated to prompt for Build Time if not found.

-- ==============================================================================
-- 0. Helper Functions (Logging, Safety, String Manipulation)
-- ==============================================================================

local log_file_path = ""

function log(msg)
    if system and system.log then system:log(msg) end
    print(msg)
end

-- Safe property getter
function safe_get(obj, key)
    local val = nil
    local ok, err = pcall(function() val = obj[key] end)
    if ok then return val else return nil end
end

-- Safe method caller
function safe_call(obj, method)
    local val = nil
    local ok, err = pcall(function() val = obj[method](obj) end)
    if ok then return val else return nil end
end

-- Split string by separator
function split(str, sep)
    local result = {}
    local regex = ("([^%s]+)"):format(sep)
    for each in str:gmatch(regex) do
        table.insert(result, each)
    end
    return result
end

-- Simple CSV Line Parser (handles basic cases)
function parse_csv_line(line, sep)
    local res = {}
    local pos = 1
    sep = sep or ","
    while true do
        local c = string.sub(line, pos, pos)
        if (c == "") then break end
        if (c == '"') then
            -- quoted value (ignore separator within)
            local txt = ""
            repeat
                local startp,endp = string.find(line, '^%b""', pos)
                txt = txt .. string.sub(line, startp+1, endp-1)
                pos = endp + 1
                c = string.sub(line, pos, pos)
                if (c == '"') then txt = txt..'"' end
            until (c ~= '"')
            table.insert(res,txt)
            if c == sep then pos = pos + 1 end
        else
            -- no quotes
            local startp,endp = string.find(line, sep, pos)
            if (startp) then
                table.insert(res,string.sub(line, pos, startp-1))
                pos = endp + 1
            else
                -- no separator found -> last field
                table.insert(res,string.sub(line, pos))
                break
            end
        end
    end
    return res
end

-- Sanitize Part Name for Matching
function clean_name(name)
    -- Remove extension
    local n = string.gsub(name, "%.%w+$", "")
    return n
end

-- ==============================================================================
-- 1. Inputs & Setup
-- ==============================================================================

-- A. Log Folder
local folder_path = ""
local ok_path, input_path = pcall(function() return system:inputdlg("Enter Path to Save Log/Output:", "Folder Path", "C:\\") end)

if ok_path and input_path and input_path ~= "" then
    folder_path = input_path
else
    folder_path = "C:\\"
end

folder_path = string.gsub(folder_path, '"', '')
if string.sub(folder_path, -1) ~= "\\" then folder_path = folder_path .. "\\" end

log_file_path = folder_path .. "export_script_log.txt"
if system and system.logtofile then
    pcall(function() system:logtofile(log_file_path) end)
end

log("--- Starting Export Script ---")
log("Working Folder: " .. folder_path)

-- B. Input CSV Path
local input_csv_path = ""
local ok_csv, in_csv = pcall(function() return system:inputdlg("Enter Path to Existing CSV:", "Input CSV Path", folder_path) end)

if ok_csv and in_csv and in_csv ~= "" then
    input_csv_path = string.gsub(in_csv, '"', '')
else
    log("No Input CSV provided. Exiting.")
    return
end
log("Input CSV: " .. input_csv_path)

-- C. Output CSV Name
local output_csv_name = ""
local ok_out, out_name = pcall(function() return system:inputdlg("Enter Output CSV Filename (e.g. results.csv):", "Output Filename", "results.csv") end)

if ok_out and out_name and out_name ~= "" then
    output_csv_name = out_name
else
    output_csv_name = "results.csv"
end
-- Ensure extension
if not string.find(output_csv_name, "%.csv$") then
    output_csv_name = output_csv_name .. ".csv"
end
local output_full_path = folder_path .. output_csv_name
log("Output CSV: " .. output_full_path)


-- ==============================================================================
-- 2. Read & Parse Input CSV
-- ==============================================================================

local input_data = {} -- Key: Part Name, Value: {Qty, Material, Link}

local f = io.open(input_csv_path, "r")
if not f then
    log("Error: Could not open input CSV.")
    return
end

local sep = "," -- Default assumption
local first_line = f:read()
if first_line then
    if string.find(first_line, ";") then sep = ";" end
end

-- Process first line if it's NOT a header, but usually it is.
-- We'll just skip the first line if it contains "Part Name"
if first_line and not string.find(string.lower(first_line), "part name") then
    -- It's data, process it
     local cols = parse_csv_line(first_line, sep)
     if #cols >= 4 then
        input_data[cols[1]] = {qty = cols[2], mat = cols[3], link = cols[4]}
     end
end

-- Read rest
for line in f:lines() do
    if line ~= "" then
        local cols = parse_csv_line(line, sep)
        if #cols >= 4 then
            local p_name = cols[1]
            local qty = cols[2]
            local mat = cols[3]
            local link = cols[4]
            input_data[p_name] = {qty = qty, mat = mat, link = link}
        end
    end
end
f:close()
log("Loaded CSV data.")


-- ==============================================================================
-- 3. Process Trays & Collect Data
-- ==============================================================================

local results = {} -- List of result rows

if not _G.netfabbtrayhandler then
    log("Error: netfabbtrayhandler not available.")
    return
end

log("Processing " .. netfabbtrayhandler.traycount .. " trays...")

for i = 0, netfabbtrayhandler.traycount - 1 do
    local tray = netfabbtrayhandler:gettray(i)
    local tray_name = "Tray " .. (i + 1)
    if tray.name then tray_name = tray.name end

    log("Inspecting " .. tray_name)

    -- A. TRAY DATA (Time, Thickness)
    local build_time = "nil"
    local layer_thick = "nil"

    -- Probing Logic
    local function find_tray_prop(keys)
        for _, k in ipairs(keys) do
            local v = safe_get(tray, k)
            if v then return v end
            -- Check slice
            local sl = safe_get(tray, "slice")
            if sl then
                local sv = safe_get(sl, k)
                if sv then return sv end
            end
        end
        return nil
    end

    local bt = find_tray_prop({"buildtime", "totalbuildtime", "estimatedbuildtime"})
    if bt then
        build_time = tostring(bt)
    else
        -- Fallback: Prompt user for Build Time
        -- We ask once per tray
        local ok_bt, input_bt = pcall(function()
            return system:inputdlg("Enter Build Time for " .. tray_name .. " (e.g. 5h 30m):", "Manual Build Time Input", "00:00:00")
        end)
        if ok_bt and input_bt and input_bt ~= "" then
            build_time = input_bt
            log("  User entered build time: " .. build_time)
        end
    end

    local lt = find_tray_prop({"layerthickness", "layer_thickness", "sliceheight"})
    if lt then layer_thick = tostring(lt) end

    -- B. FIND TARGET PART (Non-Dupe)
    if tray.root then
        for m_idx = 0, tray.root.meshcount - 1 do
            local tm = tray.root:getmesh(m_idx)
            local tm_name = tm.name

            -- Check if it is a duplicate
            if not string.find(tm_name, "%(dupe%)") and not string.find(tm_name, "dup%d+") then
                log("  Found original part: " .. tm_name)

                -- C. MESH DATA (Volumes)
                local bb_vol = "nil"
                local part_vol = "nil"
                local sup_vol = "nil"

                -- Part Volume
                local pv = safe_get(tm, "volume")
                if pv then part_vol = tostring(pv) end

                -- Support Volume
                local sup = safe_get(tm, "support")
                if sup then
                    local sv = safe_get(sup, "volume")
                    if sv then
                        sup_vol = tostring(sv)
                    else
                         local sv_m = safe_call(sup, "getvolume")
                         if sv_m then sup_vol = tostring(sv_m) end
                    end
                end

                -- Bounding Box Volume
                local ob = safe_get(tm, "outbox")
                if ob then
                    local w = ob.maxx - ob.minx
                    local d = ob.maxy - ob.miny
                    local h = ob.maxz - ob.minz
                    bb_vol = tostring(w * d * h)
                end

                -- D. MATCH WITH INPUT CSV
                local clean_key = clean_name(tm_name)
                local info = input_data[clean_key]

                local csv_qty = "nil"
                local csv_mat = "nil"
                local csv_link = "nil"

                if info then
                    csv_qty = info.qty
                    csv_mat = info.mat
                    csv_link = info.link
                else
                    log("    Warning: No matching entry in Input CSV for '" .. clean_key .. "'")
                end

                -- E. ADD TO RESULTS
                table.insert(results, {
                    name = clean_key,
                    qty = csv_qty,
                    mat = csv_mat,
                    link = csv_link,
                    bb_vol = bb_vol,
                    part_vol = part_vol,
                    sup_vol = sup_vol,
                    time = build_time,
                    layer = layer_thick
                })
            end
        end
    end
end


-- ==============================================================================
-- 4. Export Output CSV
-- ==============================================================================

local out_f, err = io.open(output_full_path, "w")
if not out_f then
    log("Error: Could not open output file for writing: " .. tostring(err))
    system:messagebox("Error: Could not open output file: " .. output_full_path)
    return
end

-- Header
out_f:write("Part name;Qty;Material;Link to CAD;BoundingBoxVol;PartVol;SupportVol;TotalBuildTime;LAyerthickness\n")

for _, r in ipairs(results) do
    local line = string.format("%s;%s;%s;%s;%s;%s;%s;%s;%s",
        r.name, r.qty, r.mat, r.link, r.bb_vol, r.part_vol, r.sup_vol, r.time, r.layer)
    out_f:write(line .. "\n")
end

out_f:close()
log("Success! Exported " .. #results .. " rows to " .. output_full_path)
if system and system.messagebox then
    pcall(function() system:messagebox("Export Complete!\nSaved to: " .. output_full_path) end)
end

log("--- Script Complete ---")
