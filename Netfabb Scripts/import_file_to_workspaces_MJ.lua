-- Batch Load Files to Separate Workspaces (Trays)
-- Modified by Jules

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- Helper: Load Mesh Files
local function loadfile(filename, ext)
    local ext = string.lower(ext)
    -- Based on Script6
    if ext == "stl" then return system:loadstl(filename)
    elseif ext == "3ds" then return system:load3ds(filename)
    elseif ext == "3mf" then return system:load3mf(filename)
    elseif ext == "amf" then return system:loadamf(filename)
    elseif ext == "gts" then return system:loadgts(filename)
    elseif ext == "ncm" then return system:loadncm(filename)
    elseif ext == "obj" then return system:loadobj(filename)
    elseif ext == "ply" then return system:loadply(filename)
    elseif ext == "svx" then return system:loadvoxel(filename)
    elseif ext == "vrml" then return system:loadvrml(filename)
    elseif ext == "wrl" then return system:loadvrml(filename)
    elseif ext == "x3d" then return system:loadx3d(filename)
    elseif ext == "x3db" then return system:loadx3d(filename)
    elseif ext == "zpr" then return system:loadzpr(filename)
    end
    return nil
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

-- Helper: Load CAD File
local function loadcadfile(filename, root)
    -- Use pcall for safety as createcadimport might fail or not exist
    local ok, err = pcall(function()
        if system.createcadimport then
            local importer = system:createcadimport(0)
            -- Parameters from Script6: 0.1 (tessellation?), 20, 20
            local model = importer:loadmodel(filename, 0.1, 20, 20)
            if model then
                local ANumberOfModels = model.entitycount
                for i = 0, ANumberOfModels - 1 do
                    local mesh = model:createsinglemesh(i)
                    if mesh then
                        root:addmesh(mesh)
                    end
                end
            end
        else
            log("CAD import not supported (system:createcadimport missing).")
        end
    end)
    if not ok then
        log("Error importing CAD file: " .. tostring(err))
    end
end

-- 1. Prompt for Directory Path
local import_path = ""
local ok_input, input_path = pcall(function() return system:showdirectoryselectdialog("Select Import Folder", "C:\\", true) end)

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
    -- pcall message box
    pcall(function() system:messagebox("Machine '" .. machine_name .. "' not found. Please ensure the machine is in your 'My Machines' list.") end)
    return
end

log("Found Workspace ID: " .. workspaceID)


-- 4. Batch Process Loop
local success_loop, err_loop = pcall(function()
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

            -- Safe check for ext
            if ext then
                local lower_ext = string.lower(ext)

                -- Prepare clean name (remove extension)
                local clean_name = file:match("(.+)%..+") or file

                local processed = false
                local partMesh = loadfile(full_path, lower_ext)
                local isCAD = is_cad_extension(lower_ext)

                if partMesh then
                    log("Processing Mesh file: " .. file)
                    -- Create a new workspace (tray)
                    local newTray = trayHandler:addworkspace(workspaceID)

                    if newTray then
                        -- Add mesh to the tray
                        local partTrayMesh = newTray.root:addmesh(partMesh)

                        if partTrayMesh then
                            partTrayMesh.name = clean_name

                            -- Manual Centering Logic
                            local mx = newTray.machinesize_x or 100
                            local my = newTray.machinesize_y or 100

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

                                local tx = (mx / 2.0) - cx
                                local ty = (my / 2.0) - cy
                                local tz = -min_z

                                partTrayMesh:translate(tx, ty, tz)
                                log("Added and centered: " .. clean_name)
                            else
                                log("Added " .. clean_name .. " but could not center (no bounding box).")
                            end
                            processed = true
                        else
                            log("Loaded but failed to add to tray: " .. file)
                        end
                    else
                         log("Failed to create new workspace for file: " .. file)
                    end

                elseif isCAD then
                    log("Processing CAD file: " .. file)
                    -- Create a new workspace (tray)
                    local newTray = trayHandler:addworkspace(workspaceID)

                    if newTray then
                        -- Capture mesh count before
                        local initial_count = newTray.root.meshcount

                        -- Import CAD
                        loadcadfile(full_path, newTray.root)

                        local final_count = newTray.root.meshcount
                        local added_count = final_count - initial_count

                        if added_count > 0 then
                            log("Imported " .. added_count .. " meshes from CAD file.")

                            -- Iterate over new meshes to rename
                            for j = initial_count, final_count - 1 do
                                 local tm = nil
                                 -- Try getmesh first (standard for TrayRoot)
                                 pcall(function() tm = newTray.root:getmesh(j) end)

                                 if not tm then
                                     -- Fallback to getchild
                                     pcall(function() tm = newTray.root:getchild(j) end)
                                 end

                                 if tm then
                                     -- Rename
                                     if added_count == 1 then
                                         tm.name = clean_name
                                     else
                                         tm.name = clean_name .. " (" .. (j - initial_count + 1) .. ")"
                                     end

                                     -- Center if single part
                                     if added_count == 1 then
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
                            processed = true
                        else
                            log("CAD import yielded no meshes for: " .. file)
                        end
                    else
                        log("Failed to create workspace for CAD file: " .. file)
                    end
                end

                if processed then
                   -- Check for GUI update
                end
            end
        end
    else
        log("Failed to list files in directory: " .. import_path)
    end
end)

if not success_loop then
    log("Critical Error in Batch Loop: " .. tostring(err_loop))
    pcall(function() system:inputdlg("Script Error", "Error", tostring(err_loop)) end)
end

-- Trigger Desktop Update
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
    log("Triggered desktop update.")
end

-- Completion message
if success_loop then
    pcall(function() system:inputdlg("Batch Import to Workspaces Complete!", "Status", "Success") end)
end
