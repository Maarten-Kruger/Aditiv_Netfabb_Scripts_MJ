-- Batch Load Files to Separate Trays
-- Author: Gemini (Based on your Netfabb Reference PDFs)

local lfs = require "lfs"

-- CONFIGURATION
-- Change this path to your folder. Note the double backslashes for Windows.
local import_path = "C:\\Users\\Maarten\\OneDrive\\Desktop"
local file_extension = ".stl"
if string.sub(import_path, -1) ~= "\\" then
    import_path = import_path .. "\\"
end

-- 2. Load the "No Build Zone" Mesh from .3mf
local noBuildPath = "C:\\Users\\Maarten\\OneDrive\\Active\\Aditiv\\Aditiv_Netfabb_Scripts_MJ\\Other Files\\No_Build.3mf"
local zoneMesh = system:load3mf(noBuildPath)

if zoneMesh then
    system:log("No Build Zone geometry loaded.")

    -- Add the mesh to the tray's root group
    meshGroup:addmesh(zoneMesh)

    -- Finds the mesh we just added to "Lock" it
    -- We assume it is the last mesh in the group
    local count = meshGroup.meshcount
    local trayMesh = meshGroup:getmesh(count)

    -- 3. Set properties to act as a "No Build Zone"
    -- "locked" tells the packer: Do not move this part.
    trayMesh:setpackingoption("restriction", "locked")

    -- Optional: Color it Red to indicate it is a danger/exclusion zone
    -- Netfabb uses standard RGB integers (often composed) or you can try setting simple indicators
    -- This property controls display color only
    trayMesh.color = 255 -- (Example: specific integer for color)

    system:log("Mesh set as Locked (No Build Zone).")
else
    system:log("Failed to load No Build Zone file.")
end


-- Get the current project
-- Note: 'system:getfabbproject()' is implied as the global project context in many versions,
-- but if you need to create a new one, use: local proj = system:newfabbproject()
-- For the active project, we usually access the 'fabbproject' global object if available,
-- or we might need to rely on the system to handle the active state.

-- Loop through the directory
for file in lfs.dir(import_path) do

    -- Check if it is a file and matches extension
    if string.sub(file, -string.len(file_extension)) == file_extension then

        local full_path = import_path .. file
        system:log("Found file: " .. file)

        -- 1. Create a new Tray for this file
        -- Syntax: fabbproject:addtray(name, size_x, size_y, size_z)
        -- We give the tray the same name as the file
        -- Adjust the machine size (250, 250, 300) to match your machine
        fabbproject:addtray(file, 250, 250, 300)

        -- 2. Load the file
        -- This imports the mesh. By default, Netfabb often places it in the
        -- currently active tray (which we just created) or the Model Parts list.
        local mesh = system:loadstl(full_path)

        -- OPTIONAL: Validating the load
        if mesh then
            system:log("Successfully loaded: " .. file)
        else
            system:log("Failed to load: " .. file)
        end

    end
end

system:messagebox("Batch Import Complete!")
