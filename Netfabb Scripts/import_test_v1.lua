-- Batch Load Files to Active Tray
-- Author: Jules (Modified from original to fix GUI update issues)

-- CONFIGURATION
-- Change this path to your folder. Note the double backslashes for Windows.
local import_path = "C:\\Users\\Maarten\\OneDrive\\Desktop"
local file_extension = "stl"
local log_file_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\import_test_log.txt"

-- Setup Logging to File
if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if not ok then
        if system.log then system:log("Failed to set log file: " .. tostring(err)) end
    end
end

-- Logging Helper
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Batch Import ---")

-- Ensure no trailing slash for getallfilesindirectory
if string.sub(import_path, -1) == "\\" then
    import_path = string.sub(import_path, 1, -2)
end

-- Check for the active tray (Build Room)
-- In Netfabb Lua Automation (Main Module), the global 'tray' represents the current build room.
local currentTray = _G.tray

if not currentTray then
    log("Error: Global 'tray' variable is missing. This script must be run from the Netfabb Desktop Automation menu.")
    -- Attempt to fallback or exit?
    -- If we can't find the tray, we can't add parts to the GUI.
    return
end

local meshGroup = currentTray.root
if not meshGroup then
    log("Error: Tray has no root mesh group.")
    return
end

-- 1. Load the "No Build Zone" Mesh from .3mf (Only once)
local noBuildPath = "C:\\Users\\Maarten\\OneDrive\\Active\\Aditiv\\Aditiv_Netfabb_Scripts_MJ\\Other Files\\No_Build.3mf"
local zoneMeshTemplate = nil

-- Check if No Build Zone is already present to avoid duplicates?
-- For now, we will just load it.
local ok_zone, loaded_zone = pcall(function() return system:load3mf(noBuildPath) end)

if ok_zone and loaded_zone then
    zoneMeshTemplate = loaded_zone
    log("No Build Zone geometry loaded.")
else
    log("Failed to load No Build Zone file template: " .. noBuildPath)
end

if zoneMeshTemplate then
    -- Add No Build Zone to the current tray
    -- Duplicate to ensure we don't modify the template directly if we were reusing it
    local zoneMesh = zoneMeshTemplate:dupe()
    local zoneTrayMesh = meshGroup:addmesh(zoneMesh)

    if zoneTrayMesh then
        -- Set properties
        zoneTrayMesh:setpackingoption("restriction", "locked")
        zoneTrayMesh.color = "FF0000" -- Red
        zoneTrayMesh.name = "No Build Zone"
        log("Added No Build Zone to tray.")
    end
end


-- 2. Load Files from Directory
local xmlfilelist = system:getallfilesindirectory(import_path)

if xmlfilelist then
    local numberoffiles = xmlfilelist.childcount
    log("Found " .. numberoffiles .. " files in directory.")

    -- Loop through the directory
    for i = 0, numberoffiles - 1 do
        local xmlChild = xmlfilelist:getchildindexed(i)
        local full_path = xmlChild:getchildvalue("filename")

        -- Extract extension and filename
        local path, file, ext = string.match(full_path, "(.-)([^\\/]-%.?([^%.\\/]*))$")

        -- Check if it is a file and matches extension (case insensitive)
        if ext and string.lower(ext) == string.lower(file_extension) then
            log("Found file: " .. file)

            -- Load the mesh
            local partMesh = system:loadstl(full_path)

            if partMesh then
                local partTrayMesh = meshGroup:addmesh(partMesh)
                if partTrayMesh then
                    partTrayMesh.name = file
                    log("Successfully loaded and added: " .. file)
                else
                    log("Loaded but failed to add to tray: " .. file)
                end
            else
                log("Failed to load: " .. file)
            end
        end
    end
else
    log("Failed to list files in directory: " .. import_path)
end

-- 3. Trigger Desktop Update
-- This ensures the GUI refreshes to show the new parts
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
    log("Triggered desktop update.")
end

-- Show completion message
local ok_msg = pcall(function() system:messagebox("Batch Import Complete! Parts added to active tray.") end)
if not ok_msg then
    log("Batch Import Complete!")
end
