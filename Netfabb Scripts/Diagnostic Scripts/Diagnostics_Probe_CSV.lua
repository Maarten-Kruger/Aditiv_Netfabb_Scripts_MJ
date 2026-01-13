-- Diagnostics_Probe_CSV.lua
-- Exports Mesh Volume, Outbox Volume, and Support Volume to CSV.

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
table.insert(results, "Mesh Name,Part Volume,Bounding Box Volume,Support Volume")

local tray = nil
if _G.tray then
    tray = _G.tray
elseif _G.netfabbtrayhandler then
    -- Try to find a non-empty tray
    for i = 0, netfabbtrayhandler.traycount - 1 do
        local t = netfabbtrayhandler:gettray(i)
        if t and t.root and t.root.meshcount > 0 then
            tray = t
            break
        end
    end
end

if tray and tray.root then
    for i = 0, tray.root.meshcount - 1 do
        local mesh = tray.root:getmesh(i)
        local name = mesh.name or "Unknown"

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

        table.insert(results, string.format("%s,%f,%f,%f", name, vol, bb_vol, sup_vol))
    end
else
    table.insert(results, "No Tray or Meshes Found,,,")
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
    if system and system.messagebox then
        pcall(function() system:messagebox("CSV Exported successfully to:\n" .. csv_path) end)
    end
else
    -- Fallback to system:logtofile if io fails
    if system and system.log then system:log("IO Library failed (" .. tostring(io_err) .. "). using system:logtofile (Will include timestamps)") end
    if system and system.logtofile then
        pcall(function() system:logtofile(csv_path) end)
        for _, line in ipairs(results) do
            if system and system.log then system:log(line) end
        end
        if system and system.messagebox then
             pcall(function() system:messagebox("CSV Logged (with timestamps) to:\n" .. csv_path) end)
        end
    end
end
