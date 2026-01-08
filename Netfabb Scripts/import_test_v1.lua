-- Batch Load Files to Separate Workspaces (Trays)
-- Modified by Jules

-- Setup Logging
local log_file_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\import_test_log.txt"

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

log("--- Starting Batch Import to Workspaces ---")

-- Check for required globals
local trayHandler = _G.netfabbtrayhandler

if not trayHandler then
    log("Error: Global 'netfabbtrayhandler' is missing. Cannot create new workspaces.")
    return
end

-- 1. Prompt for Directory
local import_path = ""
local ok_browse, path = pcall(function() return system:browsedirectory("Select Directory to Import Files From") end)

if ok_browse and path and path ~= "" then
    import_path = path
else
    -- Fallback to input dialog if browsedirectory is not available or cancelled
    local ok_input, input_path = pcall(function() return system:inputdlg("Enter Directory Path:", "Import Path", "C:\\") end)
    if ok_input and input_path and input_path ~= "" then
        import_path = input_path
    else
        log("No directory selected. Exiting.")
        return
    end
end

-- Ensure no trailing slash
if string.sub(import_path, -1) == "\\" then
    import_path = string.sub(import_path, 1, -2)
end
log("Import path: " .. import_path)


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
    -- Try to see if the user typed "Formlabs Fuse 1" instead of "Fuse 1", logic from script 45 implies partial match might work or exact string is needed.
    -- Script 45 uses "Fuse 1".
    log("Workspace instance not found for '" .. machine_name .. "'.")

    -- Option: Fallback or Exit. The prompt implies we want specific settings.
    -- Let's give one more chance or default to generic if user agrees?
    -- For now, consistent with the plan "show an error and exit".
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

                        -- Pack/Center using the Outbox Packer
                        -- This replaces manual centering and ensures it fits the machine context
                        local packer = newTray:createpacker(newTray.packingid_outbox)
                        if packer then
                            packer:pack()
                            log("Added and packed: " .. file)
                        else
                            log("Added " .. file .. " but failed to create packer.")
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
