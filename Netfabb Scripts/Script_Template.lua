-- Script Template
-- Use this template for new scripts to include standard path input and logging setup.

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
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Directory Path:", "Path Selection", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    log("No path provided. Exiting.")
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
local log_file_name = "script_log.txt" -- Change this name as needed
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
log("--- Starting Script ---")
log("Working path: " .. path_variable)

-- Example: List files in the directory
-- local files = system:getallfilesindirectory(path_variable)
