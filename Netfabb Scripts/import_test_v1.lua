-- Batch Load Files to Separate Trays
-- Author: Gemini (Based on your Netfabb Reference PDFs)
-- Modified by Jules to fix logging and fabbproject access

-- CONFIGURATION
-- Change this path to your folder. Note the double backslashes for Windows.
local import_path = "C:\\Users\\Maarten\\OneDrive\\Desktop"
local file_extension = "stl"
local log_file_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\import_test_log.txt"

-- Setup Logging to File
-- 'io' library is unavailable, so we use system:logtofile
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

-- Ensure no trailing slash for getallfilesindirectory (Netfabb usually handles it, but consistency is good)
if string.sub(import_path, -1) == "\\" then
    import_path = string.sub(import_path, 1, -2)
end

-- 2. Load the "No Build Zone" Mesh from .3mf
local noBuildPath = "C:\\Users\\Maarten\\OneDrive\\Active\\Aditiv\\Aditiv_Netfabb_Scripts_MJ\\Other Files\\No_Build.3mf"
local zoneMeshTemplate = system:load3mf(noBuildPath)

if zoneMeshTemplate then
    log("No Build Zone geometry loaded.")
else
    log("Failed to load No Build Zone file template.")
end


-- Get the current project
-- Note: 'system:getfabbproject()' is implied as the global project context in many versions,
-- but if you need to create a new one, use: local proj = system:newfabbproject()
-- For the active project, we usually access the 'fabbproject' global object if available.

-- Attempt to retrieve fabbproject if it is nil
-- We use a local variable to hold the reference, initializing from global if present
local fabbproject = fabbproject

if not fabbproject then
    -- Try system:getfabbproject() using pcall
    local ok, proj = pcall(function() return system:getfabbproject() end)
    if ok and proj then
        fabbproject = proj
    else
        -- Try system:getactiveproject() using pcall
        local ok2, proj2 = pcall(function() return system:getactiveproject() end)
        if ok2 and proj2 then
            fabbproject = proj2
        end
    end
end

if not fabbproject then
    log("Error: 'fabbproject' global is nil and could not be retrieved via system methods. Attempting to create a new project instance...")
    -- Fallback: Create a new fabbproject instance
    local ok_new, new_proj = pcall(function() return system:newfabbproject() end)
    if ok_new and new_proj then
        fabbproject = new_proj
        log("Warning: Created a new fabbproject instance. Changes might not appear in the active GUI.")
    else
        log("Error: Failed to create a new fabbproject instance.")
    end
end

if fabbproject then
    log("fabbproject is available.")
end

-- Use system:getallfilesindirectory instead of lfs
local xmlfilelist = system:getallfilesindirectory(import_path)

if xmlfilelist then
    local numberoffiles = xmlfilelist.childcount
    log("Found " .. numberoffiles .. " files in directory.")

    -- Loop through the directory
    for i = 0, numberoffiles - 1 do
        local xmlChild = xmlfilelist:getchildindexed(i)
        local full_path = xmlChild:getchildvalue("filename")

        -- Extract extension and filename
        -- Pattern matches: path, filename, extension
        local path, file, ext = string.match(full_path, "(.-)([^\\/]-%.?([^%.\\/]*))$")

        -- Check if it is a file and matches extension (case insensitive)
        if ext and string.lower(ext) == string.lower(file_extension) then

            log("Found file: " .. file)

            -- 1. Create a new Tray for this file
            -- Syntax: fabbproject:addtray(name, size_x, size_y, size_z)
            -- We give the tray the same name as the file
            -- Adjust the machine size (250, 250, 300) to match your machine
            if fabbproject then
                fabbproject:addtray(file, 250, 250, 300)

                -- Get the newly created tray (assumed to be the last one)
                local trayIndex = fabbproject.traycount - 1
                local newTray = fabbproject:gettray(trayIndex)

                if newTray then
                    local meshGroup = newTray.root

                    -- 2. Add No Build Zone
                    if zoneMeshTemplate then
                        -- Duplicate the mesh for the new tray to avoid ownership issues
                        local zoneMesh = zoneMeshTemplate:dupe()
                        local zoneTrayMesh = meshGroup:addmesh(zoneMesh)

                        if zoneTrayMesh then
                            -- 3. Set properties to act as a "No Build Zone"
                            -- "locked" tells the packer: Do not move this part.
                            zoneTrayMesh:setpackingoption("restriction", "locked")

                            -- Optional: Color it Red to indicate it is a danger/exclusion zone
                            -- Using hex string "FF0000" for Red based on Example Code
                            zoneTrayMesh.color = "FF0000"
                        end
                    end

                    -- 3. Load and Add Part
                    -- This imports the mesh.
                    local partMesh = system:loadstl(full_path)

                    -- OPTIONAL: Validating the load
                    if partMesh then
                        local partTrayMesh = meshGroup:addmesh(partMesh)
                        if partTrayMesh then
                            log("Successfully loaded and added: " .. file)
                        else
                            log("Loaded but failed to add to tray: " .. file)
                        end
                    else
                        log("Failed to load: " .. file)
                    end
                else
                    log("Failed to retrieve new tray for: " .. file)
                end
            else
                 log("Skipping tray creation for " .. file .. " because fabbproject is missing.")
            end
        end
    end
else
    log("Failed to list files in directory: " .. import_path)
end

-- Safely attempt to show messagebox, falling back to log if it fails or doesn't exist
local ok_msg = pcall(function() system:messagebox("Batch Import Complete!") end)
if not ok_msg then
    log("Batch Import Complete!")
end
