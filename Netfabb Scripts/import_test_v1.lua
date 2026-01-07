-- Batch Load Files to Separate Trays and Center
-- Author: Jules (Modified from original)

-- CONFIGURATION
local import_path = "C:\\Users\\Maarten\\OneDrive\\Desktop"
local file_extension = "stl"
local log_file_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\import_test_log.txt"

-- Setup Logging
if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if not ok then
        if system.log then system:log("Failed to set log file: " .. tostring(err)) end
    end
end

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Batch Import V2 ---")

-- Ensure no trailing slash
if string.sub(import_path, -1) == "\\" then
    import_path = string.sub(import_path, 1, -2)
end

-- Check for fabbproject (Required for creating trays)
local project = _G.fabbproject

if not project then
    log("Error: Global 'fabbproject' is missing. This script requires the project context to create new trays.")
    -- Try to fallback to system:getfabbproject() if available, but usually _G.fabbproject is the way.
    -- If we are in a context without a project, we can't fulfill the requirement of multiple trays properly.
    return
end

-- Load Files from Directory
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

        -- Check extension
        if ext and string.lower(ext) == string.lower(file_extension) then
            log("Processing file: " .. file)

            -- Load the mesh
            local partMesh = system:loadstl(full_path)

            if partMesh then
                -- Create a new tray for this mesh
                project:addtray()
                -- Retrieve the newly created tray (it's the last one)
                local newTray = project:gettray(project.traycount - 1)

                if newTray then
                    -- Get the root mesh group
                    local meshGroup = newTray.root

                    -- Add mesh to the tray
                    local partTrayMesh = meshGroup:addmesh(partMesh)

                    if partTrayMesh then
                        partTrayMesh.name = file

                        -- Center the mesh
                        -- We assume partTrayMesh has an 'outbox' property (newer API)
                        -- or use calcoutbox() if needed. Using 'outbox' as per recent examples.
                        local outbox = partTrayMesh.outbox

                        if outbox then
                            local cx = (outbox.minx + outbox.maxx) / 2.0
                            local cy = (outbox.miny + outbox.maxy) / 2.0
                            local min_z = outbox.minz

                            -- Translate: Center on XY, move Z min to 0
                            partTrayMesh:translate(-cx, -cy, -min_z)
                            log("Added and centered: " .. file)
                        else
                             -- Fallback if outbox property is missing?
                             -- Try calcoutbox method
                             local ok_box, box = pcall(function() return partTrayMesh:calcoutbox() end)
                             if ok_box and box then
                                local cx = (box.minx + box.maxx) / 2.0
                                local cy = (box.miny + box.maxy) / 2.0
                                local min_z = box.minz
                                partTrayMesh:translate(-cx, -cy, -min_z)
                                log("Added and centered (via calcoutbox): " .. file)
                             else
                                log("Added " .. file .. " but could not center (no bounding box info).")
                             end
                        end
                    else
                        log("Loaded but failed to add to tray: " .. file)
                    end
                else
                    log("Failed to get the new tray for file: " .. file)
                end
            else
                log("Failed to load: " .. file)
            end
        end
    end
else
    log("Failed to list files in directory: " .. import_path)
end

-- Trigger Desktop Update
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
    log("Triggered desktop update.")
end

-- Completion message
local ok_msg = pcall(function() system:messagebox("Batch Import Complete! Parts added to separate trays.") end)
if not ok_msg then
    log("Batch Import Complete!")
end
