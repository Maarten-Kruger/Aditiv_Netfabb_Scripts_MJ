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

log("--- Starting Batch Import V3 ---")

-- Ensure no trailing slash
if string.sub(import_path, -1) == "\\" then
    import_path = string.sub(import_path, 1, -2)
end

-- Check for required globals
-- In Desktop Automation, 'tray' is the current buildroom.
local currentTray = _G.tray
local trayHandler = _G.netfabbtrayhandler

if not currentTray then
    log("Error: Global 'tray' is missing. This script must be run from the Netfabb Desktop Automation menu.")
    return
end

if not trayHandler then
    log("Error: Global 'netfabbtrayhandler' is missing. Cannot create new trays.")
    return
end

-- Get machine dimensions from the current tray to apply to new trays
local machine_x = currentTray.machinesize_x or 250
local machine_y = currentTray.machinesize_y or 250
local machine_z = currentTray.machinesize_z or 200

log("Using machine dimensions: " .. machine_x .. "x" .. machine_y .. "x" .. machine_z)


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
                -- Create a new tray for this mesh using netfabbtrayhandler
                -- addtray returns the new tray object directly
                local newTray = trayHandler:addtray(file, machine_x, machine_y, machine_z)

                if newTray then
                    -- Get the root mesh group
                    local meshGroup = newTray.root

                    -- Add mesh to the tray
                    local partTrayMesh = meshGroup:addmesh(partMesh)

                    if partTrayMesh then
                        partTrayMesh.name = file

                        -- Center the mesh
                        -- We assume partTrayMesh has an 'outbox' property (newer API)
                        -- or use calcoutbox() if needed.
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
                    log("Failed to create new tray for file: " .. file)
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
