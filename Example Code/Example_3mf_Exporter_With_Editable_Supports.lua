-- TESTER SCRIPT: Batch Export to 3MF with Supports
-- This script collects all parts in the current tray and exports them to a single .3mf file
-- preserving their supports as separate, detachable items.

-- 1. HELPER: Function to collect all meshes (recursive to handle groups)
local function insertMeshesIntoTable(meshgroup, Outtable)
    -- Add all meshes in this group
    for mesh_index = 0, meshgroup.meshcount - 1 do
        local traymesh = meshgroup:getmesh(mesh_index)
        table.insert(Outtable, traymesh)
    end
    -- Recursively check subgroups
    for group_index = 0, meshgroup.groupcount - 1 do
        local subgroup = meshgroup:getsubgroup(group_index)
        insertMeshesIntoTable(subgroup, Outtable)
    end
end

-- 2. MAIN EXECUTION
if tray == nil then
    system:log("Error: No active tray found.")
else
    system:log("Starting 3MF Export Tester...")

    -- Collect all parts
    local meshes = {}
    insertMeshesIntoTable(tray.root, meshes)

    if #meshes == 0 then
        system:log("Warning: Tray is empty. Nothing to export.")
    else
        -- Create the Exporter
        local exporter = system:create3mfexporter()


        -- Add each part to the exporter
        for i, traymesh in pairs(meshes) do
            system:log("Processing: " .. traymesh.name)

            -- Add the Part Geometry
            local luamesh = traymesh.mesh
            local entry = exporter:add(luamesh)


            -- Set Metadata
            entry.name = traymesh.name
            entry.grouppath = "3mfexport/parts"

            -- Check for and Attach Supports
            if traymesh.hassupport then
                system:log("  > Found supports. Attaching...")
                -- This method links the support mesh to the part in the 3MF structure
                entry:setsupport(traymesh.support)

            end
        end

        -- Define Output Path (Desktop for easy access)
        -- Note: Ensure this path is valid for your user (e.g., C:/Temp/ or similar)
        local out_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\Batch_Export_With_Supports.3mf"

        -- Create directory if it doesn't exist (optional, mostly system:log checks)
        system:log("Exporting to: " .. out_path)

        -- Write the file
        exporter:exporttofile(out_path)


        system:log("Export Complete.")
        system:messagedlg("Export successful!\nFile saved to: " .. out_path)
    end
end
