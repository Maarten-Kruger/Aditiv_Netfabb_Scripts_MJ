-- Import Parts by Quantity from CSV
-- Based on Netfabb Scripts/import_file_to_workspaces_MJ.lua and Example Code/Simple_STEP_Import.lua

-- Defaults for Import Settings
local default_deviation = 0.1
local default_angle_tol = 20
local default_edge_len = 5

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- Helper: Check CAD Extension
local function is_cad_extension(ext)
    local ext = string.lower(ext)
    local cad_exts = {
        ["3dm"] = true, ["3dxml"] = true, ["stp"] = true, ["step"] = true,
        ["asm"] = true, ["catpart"] = true, ["cgr"] = true, ["dwg"] = true,
        ["fbx"] = true, ["g"] = true, ["iam"] = true, ["igs"] = true, ["iges"] = true,
        ["ipt"] = true, ["jt"] = true, ["model"] = true, ["neu"] = true,
        ["par"] = true, ["prt"] = true, ["psm"] = true, ["rvt"] = true,
        ["sat"] = true, ["skp"] = true, ["sldprt"] = true, ["wire"] = true,
        ["x_b"] = true, ["x_t"] = true, ["xas"] = true, ["xpr"] = true
    }
    return cad_exts[ext]
end

-- 1. Prompt for Directory Path (From import_file_to_workspaces_MJ.lua)
log("--- Starting Import Part Quantity Script ---")
local import_path = ""

local ok_input, input_path = false, nil
local default_path = "C:\\"
local title = "Select Import Folder"

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
    import_path = input_path
else
    log("No directory selected or cancelled. Exiting.")
    pcall(function() system:inputdlg("No directory selected. Exiting.", "Error", "Error") end)
    return
end

-- Clean up path: Remove double quotes
import_path = string.gsub(import_path, '"', '')

if import_path == "" then
     log("Invalid path (empty after cleanup).")
     pcall(function() system:inputdlg("Invalid path provided.", "Error", "Error") end)
     return
end

-- Ensure trailing backslash
if string.sub(import_path, -1) ~= "\\" then
    import_path = import_path .. "\\"
end

-- Setup Logging
local log_file_path = import_path .. "import_quantity_log.txt"
log("Log file path: " .. log_file_path)

if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if not ok then
        log("Failed to set log file: " .. tostring(err))
    end
end

log("Import path: " .. import_path)

-- Check for required globals
local trayHandler = _G.netfabbtrayhandler

if not trayHandler then
    log("Error: Global 'netfabbtrayhandler' is missing. Cannot create new workspaces.")
    pcall(function() system:inputdlg("Global 'netfabbtrayhandler' is missing.", "Critical Error", "Error") end)
    return
end

-- 2. Prompt for Import Settings (Combined Popup)
local settings_default_str = string.format("%s, %s, %s", default_deviation, default_angle_tol, default_edge_len)
local ok_set, input_set = pcall(function()
    return system:inputdlg("Enter Deviation (mm), Angle (deg), Edge Length (mm):", "Import Settings", settings_default_str)
end)

if ok_set and input_set and input_set ~= "" then
    local parts = {}
    for w in string.gmatch(input_set, "([^,]+)") do
        table.insert(parts, tonumber(w))
    end

    if #parts >= 1 and parts[1] then default_deviation = parts[1] end
    if #parts >= 2 and parts[2] then default_angle_tol = parts[2] end
    if #parts >= 3 and parts[3] then default_edge_len = parts[3] end
end

log("Import Settings: Deviation=" .. default_deviation .. ", Angle=" .. default_angle_tol .. ", EdgeLen=" .. default_edge_len)

-- 3. Prompt for Machine Name
local machine_name = "Formlabs Fuse 1" -- Default
local ok_mach, input_mach = pcall(function() return system:inputdlg("Enter Machine Name for Workspace (e.g., 'Fuse 1'):", "Machine Selection", machine_name) end)
if ok_mach and input_mach and input_mach ~= "" then
    machine_name = input_mach
end
log("Selected machine name: " .. machine_name)

-- 4. Get Workspace ID
local workspaceID = trayHandler:getmachineidentifier(machine_name)

if workspaceID == "" then
    log("Workspace instance not found for '" .. machine_name .. "'.")
    pcall(function() system:inputdlg("Machine '" .. machine_name .. "' not found. Please ensure the machine is in your 'My Machines' list.", "Error", "Error") end)
    return
end
log("Found Workspace ID: " .. workspaceID)

-- Helper: Load CAD File and return list of meshes
local function get_cad_meshes(filename)
    local importer = nil
    -- Iterating indices 0-10 to find a working importer kernel
    for i = 0, 10 do
        local ok, res = pcall(function() return system:createcadimport(i) end)
        if ok and res then
            importer = res
            -- log("Created CAD importer with index: " .. i)
            break
        end
    end

    if not importer then
        log("Error: Failed to create CAD importer. No working kernel found.")
        return {}
    end

    -- Load Model
    local cadmodel = nil
    local ok_load, res_load = pcall(function()
        return importer:loadmodel(filename, default_deviation, default_angle_tol, default_edge_len)
    end)

    if ok_load and res_load then
        cadmodel = res_load
        local meshes = {}
        local ANumberOfModels = cadmodel.entitycount

        for i = 0, ANumberOfModels - 1 do
            local mesh = nil
            local ok_m, res_m = pcall(function() return cadmodel:createsinglemesh(i) end)
            if ok_m and res_m then
                table.insert(meshes, res_m)
            end
        end

        return meshes
    else
        log("Failed to load CAD model: " .. tostring(res_load))
        return {}
    end
end

-- Helper: Load Standard Mesh
local function loadfile(filename, ext)
    local ext = string.lower(ext)
    if ext == "stl" then return system:loadstl(filename)
    elseif ext == "3mf" then return system:load3mf(filename)
    elseif ext == "obj" then return system:loadobj(filename)
    end
    return nil
end

-- Helper: Read File Content (Safe Fallback)
local function read_file_safe(path)
    -- 1. Try io.open
    if _G.io and _G.io.open then
        local f, err = io.open(path, "r")
        if f then
            local content = f:read("*all")
            f:close()
            return content
        else
            log("io.open failed: " .. tostring(err))
        end
    else
        log("io library not available.")
    end

    -- 2. Try system:loadtextfile (hypothetical, but common in automation)
    local ok, res = pcall(function() return system:loadtextfile(path) end)
    if ok then
         if res then
             -- Ensure it is a string
             local t = type(res)
             log("system:loadtextfile returned type: " .. t)
             if t == "string" then
                 return res
             elseif t == "table" then
                 log("Converting table from loadtextfile to string (concatenating lines).")
                 return table.concat(res, "\n")
             elseif t == "userdata" then
                 log("Converting userdata from loadtextfile to string.")
                 return tostring(res)
             else
                 log("Unexpected type from loadtextfile.")
                 return tostring(res)
             end
         else
             log("system:loadtextfile returned nil.")
         end
    else
         log("system:loadtextfile failed or missing.")
    end

    return nil
end

-- 5. Main Execution: Find CSV and Process
local success_main, err_main = pcall(function()
    -- Find CSV
    local filelist = system:getallfilesindirectory(import_path)
    local csv_path = nil

    if filelist then
        for i = 0, filelist.childcount - 1 do
            local fileChild = filelist:getchildindexed(i)
            local fname = fileChild:getchildvalue("filename")
            if string.match(string.lower(fname), "%.csv$") then
                csv_path = fname
                break
            end
        end
    end

    if not csv_path then
        error("No CSV file found in " .. import_path)
    end

    log("Found CSV: " .. csv_path)

    -- Read CSV
    local content = read_file_safe(csv_path)

    if not content then
        -- Last Resort: Ask user to paste content
        log("Could not read file via script. Requesting manual input.")
        local msg = "Script cannot read files (IO restricted). Please Open the CSV, Copy All text, and Paste it here:"
        local ok_in, input_in = pcall(function() return system:inputdlg(msg, "Manual CSV Import", "") end)
        if ok_in and input_in and input_in ~= "" then
            content = input_in
            log("User provided CSV content manually.")
        else
            error("Could not read CSV file and no manual input provided.")
        end
    end

    -- Force content to string to avoid Userdata errors with string methods
    content = tostring(content)

    -- Parse CSV lines
    local lines = {}
    -- Handle both \n and \r\n, using string.gmatch for safety
    for s in string.gmatch(content, "[^\r\n]+") do
        table.insert(lines, s)
    end

    if #lines < 2 then error("CSV file is empty or missing header.") end

    -- Parse Header
    local header = lines[1]
    local cols = {}
    local idx = 1
    for w in string.gmatch(header, "([^,]+)") do
        cols[string.lower(w:match("^%s*(.-)%s*$"))] = idx -- trim whitespace
        idx = idx + 1
    end

    local idx_name = cols["part name"] or cols["partname"]
    local idx_num = cols["part number"] or cols["partnumber"]
    local idx_qty = cols["quantity"] or cols["qty"]

    if not idx_name or not idx_num or not idx_qty then
        error("CSV missing required columns (Part name, Part number, Quantity). Found: " .. header)
    end

    -- Process Rows
    for i = 2, #lines do
        local line = lines[i]
        if line and line ~= "" then
            -- Simple comma splitting
            local vals = {}
            for w in string.gmatch(line, "([^,]+)") do
                table.insert(vals, w:match("^%s*(.-)%s*$"))
            end

            -- Handle potential empty trailing columns
            if #vals >= math.max(idx_name, idx_num, idx_qty) then
                local p_name = vals[idx_name]
                local p_num = vals[idx_num]
                local qty = tonumber(vals[idx_qty]) or 1

                log("Row " .. i .. ": Name=" .. p_name .. ", Num=" .. p_num .. ", Qty=" .. qty)

                -- Clean Part Number: "OR-00600-1" -> "OR-00600"
                -- Pattern: Match everything up to the last dash
                local clean_num = p_num:match("^(.*)%-[^%-]*$")
                if not clean_num then clean_num = p_num end -- If no dash, keep original

                -- Construct Folder Path
                local subfolder = import_path .. clean_num .. "\\"
                local file_path = subfolder .. p_name

                -- Check if file exists (try to open)
                local file_exists = false
                if system.fileexists then
                    file_exists = system:fileexists(file_path)
                else
                    file_exists = true
                end

                if file_exists then
                    log("  Processing File: " .. file_path)

                    -- Create Workspace
                    local newTray = trayHandler:addworkspace(workspaceID)
                    if newTray then
                        -- Import Logic
                        local ext = file_path:match("%.([^%.]+)$")
                        local lower_ext = string.lower(ext or "")
                        local isCAD = is_cad_extension(lower_ext)

                        local meshes_to_add = {}

                        if isCAD then
                            meshes_to_add = get_cad_meshes(file_path)
                        else
                            local mesh = loadfile(file_path, lower_ext)
                            if mesh then
                                table.insert(meshes_to_add, mesh)
                            end
                        end

                        if #meshes_to_add > 0 then
                            log("    Adding " .. qty .. " copies of " .. #meshes_to_add .. " meshes.")

                            for k = 1, qty do
                                for m_idx, mesh in ipairs(meshes_to_add) do
                                    local tm = newTray.root:addmesh(mesh)
                                    if tm then
                                         -- Construct Name
                                         local base_name = p_name
                                         -- If multiple meshes from one file, append mesh index
                                         if #meshes_to_add > 1 then
                                             base_name = base_name .. "_m" .. m_idx
                                         end

                                         if k == 1 then
                                             tm.name = base_name
                                         else
                                             tm.name = base_name .. " (" .. k .. ")"
                                         end

                                         -- Center
                                         local mx = newTray.machinesize_x or 100
                                         local my = newTray.machinesize_y or 100

                                         local outbox = tm.outbox
                                         if not outbox then pcall(function() tm:calcoutbox() end); outbox = tm.outbox end
                                         if outbox then
                                             local cx = (outbox.minx + outbox.maxx) / 2.0
                                             local cy = (outbox.miny + outbox.maxy) / 2.0
                                             local min_z = outbox.minz
                                             local tx = (mx / 2.0) - cx
                                             local ty = (my / 2.0) - cy
                                             local tz = -min_z
                                             tm:translate(tx, ty, tz)
                                         end
                                    end
                                end
                            end
                        else
                            log("  Failed to load meshes from file (0 meshes returned or import failed): " .. file_path)
                        end
                    else
                        log("  Failed to create workspace.")
                    end
                else
                    log("  File not found (system:fileexists returned false): " .. file_path)
                end
            end
        end
    end

end)

if not success_main then
    log("Critical Error: " .. tostring(err_main))
    pcall(function() system:inputdlg("Script Error: " .. tostring(err_main), "Error", "Error") end)
end

-- Trigger Desktop Update
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

if success_main then
    pcall(function() system:inputdlg("Import Quantity Script Complete!", "Status", "Success") end)
end
