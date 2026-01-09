-- Batch Load Files to Separate Workspaces (Trays)
-- Modified by Jules

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- 1. Prompt for Directory Path
local import_path = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Directory Path:", "Import Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    import_path = input_path
else
    log("No directory selected. Exiting.")
    return
end

-- Clean up path: Remove double quotes
import_path = string.gsub(import_path, '"', '')

if import_path == "" then
     log("Invalid path (empty after cleanup).")
     return
end

-- Ensure trailing backslash
if string.sub(import_path, -1) ~= "\\" then
    import_path = import_path .. "\\"
end

-- Setup Logging
local log_file_path = import_path .. "import_log.txt"

if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if not ok then
        log("Failed to set log file: " .. tostring(err))
    end
end

log("--- Starting Batch Import to Workspaces ---")
log("Import path: " .. import_path)

-- Check for required globals
local trayHandler = _G.netfabbtrayhandler

if not trayHandler then
    log("Error: Global 'netfabbtrayhandler' is missing. Cannot create new workspaces.")
    return
end


-- 2. Prompt for Machine Name
local machine_name = "Formlabs Fuse 1" -- Default
local ok_mach, input_mach = pcall(function() return system:inputdlg("Enter Machine Name for Workspace (e.g., 'Fuse 1'):", "Machine Selection", machine_name) end)
if ok_mach and input_mach and input_mach ~= "" then
    machine_name = input_mach
end
log("Selected machine name: " .. machine_name)

-- 3. Get Workspace ID
local workspaceID = trayHandler:getmachineidentifier(machine_name)

if workspaceID == "" then
    log("Workspace instance not found for '" .. machine_name .. "'.")
    system:messagebox("Machine '" .. machine_name .. "' not found. Please ensure the machine is in your 'My Machines' list.")
    return
end

log("Found Workspace ID: " .. workspaceID)


-- 4. Batch Process Loop
local file_extension = "stl" -- Could also be prompted or support multiple
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
                -- Create a new workspace (tray)
                local newTray = trayHandler:addworkspace(workspaceID)

                if newTray then
                    -- Add mesh to the tray
                    local partTrayMesh = newTray.root:addmesh(partMesh)

                    if partTrayMesh then
                        partTrayMesh.name = file

                        -- Manual Centering Logic
                        -- We use manual translation because the packer sometimes fails to place parts inside the build volume.

                        -- Get machine dimensions from the new tray
                        local mx = newTray.machinesize_x or 100
                        local my = newTray.machinesize_y or 100
                        local mz = newTray.machinesize_z or 100

                        -- Get Part Bounding Box
                        local outbox = partTrayMesh.outbox
                        if not outbox then
                             pcall(function() partTrayMesh:calcoutbox() end)
                             outbox = partTrayMesh.outbox
                        end

                        if outbox then
                            local cx = (outbox.minx + outbox.maxx) / 2.0
                            local cy = (outbox.miny + outbox.maxy) / 2.0
                            local min_z = outbox.minz

                            -- Calculate translation to center on XY and sit on Z=0
                            local tx = (mx / 2.0) - cx
                            local ty = (my / 2.0) - cy
                            local tz = -min_z

                            -- Apply translation
                            partTrayMesh:translate(tx, ty, tz)
                            log("Added and centered: " .. file .. " at (" .. tx .. ", " .. ty .. ", " .. tz .. ")")
                        else
                            log("Added " .. file .. " but could not center (no bounding box info).")
                        end

                    else
                        log("Loaded but failed to add to tray: " .. file)
                    end
                else
                    log("Failed to create new workspace for file: " .. file)
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
local ok_msg = pcall(function() system:messagebox("Batch Import to Workspaces Complete!") end)
if not ok_msg then
    log("Batch Import Complete!")
end
