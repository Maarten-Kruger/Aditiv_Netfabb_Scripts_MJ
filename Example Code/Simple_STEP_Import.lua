-- Simple STEP Import Script
-- Based on Script_Template.lua

-- Standard Logging Function
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- 1. Prompt for Directory Path
-- This popup asks the user for a filepath (or directory path).
-- It allows pasting paths that might contain double quotes (common in Windows).
local path_variable = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Path to Save Log File:", "Import Log Folder Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    log("No directory selected. Exiting.")
    return
end

-- 2. Correctly Format the Path
-- Remove double quotes
path_variable = string.gsub(path_variable, '"', '')

-- Check if empty after cleanup
if path_variable == "" then
    log("Invalid path (empty after cleanup).")
    return
end

-- Add double backslash (trailing slash) if necessary
-- This ensures we can append filenames easily.
if string.sub(path_variable, -1) ~= "\\" then
    path_variable = path_variable .. "\\"
end

-- 3. Save to Local Variable
-- 'path_variable' is now the local variable holding the correct path.
-- You can rename 'path_variable' to 'import_path', 'export_path', etc.

-- 4. Setup Logging to File at that Path
local log_file_name = "Simple_STEP_Import_Log.txt" -- Changed name
local log_file_path = path_variable .. log_file_name

if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if not ok then
        log("Failed to set log file: " .. tostring(err))
    else
        log("Log file set to: " .. log_file_path)
    end
end

-- START YOUR SCRIPT LOGIC HERE --
log("--- Starting Simple STEP Import Script ---")
log("Working path for logs: " .. path_variable)

-- Hardcoded STEP file path
local step_file_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\1111PAT Mi v7.3 Lid step.step"
log("Target STEP File Path: " .. step_file_path)

-- Create CAD Importer
local importer = nil
log("Attempting to create CAD importer...")
-- Iterating indices 0-10 to find a working importer kernel
for i = 0, 10 do
    local ok, res = pcall(function() return system:createcadimport(i) end)
    if ok and res then
        importer = res
        log("Success: Created CAD importer with index: " .. i)
        break
    end
end

if not importer then
    log("Error: Failed to create CAD importer. No working kernel found.")
    return
end

-- Load Model
-- Syntax: importer:loadmodel(filename, surface_deviation, angle_tolerance, max_edge_length)
-- Using values from the user request: 0.1, 20, 5
log("Loading model from: " .. step_file_path)
local cadmodel = nil
local ok_load, res_load = pcall(function()
    return importer:loadmodel(step_file_path, 0.1, 20, 5)
end)

if ok_load and res_load then
    cadmodel = res_load
    log("Success: Model loaded.")

    -- Convert to Mesh
    log("Converting CAD model to mesh...")
    -- Try index 1 first, then 0
    local mesh = nil
    local ok_mesh, res_mesh = pcall(function() return cadmodel:createsinglemesh(1) end)

    if ok_mesh and res_mesh then
        mesh = res_mesh
        log("Success: Mesh created using index 1.")
    else
        log("Retrying mesh creation with index 0...")
        ok_mesh, res_mesh = pcall(function() return cadmodel:createsinglemesh(0) end)
        if ok_mesh and res_mesh then
            mesh = res_mesh
            log("Success: Mesh created using index 0.")
        end
    end

    if mesh then
        -- Add to Tray
        local ok_add, err_add = pcall(function() system:addmesh(mesh) end)
        if ok_add then
            log("Success: Mesh added to tray.")
            pcall(function() system:inputdlg("Import Successful!", "Success", "OK") end)
        else
            log("Error: Failed to add mesh to tray. " .. tostring(err_add))
        end
    else
        log("Error: Failed to create mesh from CAD model.")
        pcall(function() system:inputdlg("Error: Failed to create mesh.", "Error", "OK") end)
    end

else
    log("Error: Failed to load model. " .. tostring(res_load))
    pcall(function() system:inputdlg("Error: Failed to load model. Check log for details.", "Error", "OK") end)
end

log("--- Script Finished ---")
