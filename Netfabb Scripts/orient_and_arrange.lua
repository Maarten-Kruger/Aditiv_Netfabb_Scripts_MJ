-- Orient and Arrange Selected Part
-- This script orients the currently selected part(s) and then arranges them
-- while keeping other parts locked in place.

-- Logging setup
local function log(msg)
    if system and system.log then system:log(msg) end
    print(msg)
end

log("--- Start Orient and Arrange Script ---")

if not tray or not tray.root then
    log("Error: tray or tray.root is not available.")
    return
end

local root = tray.root

-- 1. Identify Selected Parts
local selected_meshes = {}
local selected_indices = {} -- Keep track of indices/IDs if needed, but objects are safer

-- Helper to check selection
-- We iterate all meshes and check .selected property
local mesh_count = 0
pcall(function() mesh_count = root.meshcount end)

log("Scanning " .. mesh_count .. " meshes for selection...")

for i = 0, mesh_count - 1 do
    local mesh = root:getmesh(i)
    if mesh then
        local is_selected = false
        pcall(function() is_selected = mesh.selected end)
        if is_selected then
            table.insert(selected_meshes, mesh)
            log("Selected mesh found: " .. mesh.name)
        end
    end
end

if #selected_meshes == 0 then
    log("No meshes selected. Please select a part to orient and arrange.")
    return
end

-- 2. Orient Selected Parts
local new_meshes = {} -- Store the new (oriented) meshes to arrange later

for _, old_traymesh in ipairs(selected_meshes) do
    log("Orienting: " .. old_traymesh.name)

    -- We follow the pattern: Duplicate Geometry -> Apply Current Transform -> Orient -> Add New -> Remove Old
    local luamesh = old_traymesh.mesh
    local old_matrix = old_traymesh.matrix
    local original_name = old_traymesh.name

    -- Duplicate to work on independent geometry
    local work_mesh = nil
    if luamesh.dupe then
        work_mesh = luamesh:dupe()
    else
        -- Fallback if dupe not available (should be), use original (risky if shared)
        log("Warning: .dupe() not found, using original mesh geometry.")
        work_mesh = luamesh
    end

    -- Bake current position into geometry so orienter sees world space
    work_mesh:applymatrix(old_matrix)

    -- Create and run orienter
    local orienter = work_mesh:create_partorienter()
    if orienter then
        orienter.cutoff_degree = 45
        orienter.smallest_distance_between_minima_degree = 30
        orienter.rotation_axis = 'arbitrary'
        orienter.distance_from_platform = 0 -- We want it on the platform (or close)
        orienter.support_bottom_surface = true

        log("  Searching for optimal orientation...")
        orienter:search_orientation_with_progress()

        local orientation = orienter:get_best_solution_for('support_volume')
        local solution_matrix = orienter:get_matrix_from_solution(orientation)

        -- Apply orientation to the work mesh
        work_mesh:applymatrix(solution_matrix)

        -- Add as new mesh to tray
        local new_traymesh = root:addmesh(work_mesh)
        new_traymesh.name = original_name -- Keep original name

        -- Store for arrangement
        table.insert(new_meshes, new_traymesh)

        -- Remove the old mesh
        root:removemesh(old_traymesh)
        log("  Orientation applied. Old mesh removed, new mesh added.")
    else
        log("  Error: Failed to create part orienter.")
        -- If failed, keep the old one for arrangement?
        table.insert(new_meshes, old_traymesh)
    end
end

-- 3. Arrange (Pack)
log("Preparing to arrange...")

-- Update mesh count as we added/removed things
local current_mesh_count = root.meshcount

-- Configure packing restrictions
for i = 0, current_mesh_count - 1 do
    local mesh = root:getmesh(i)

    -- Check if this mesh is one of our new oriented meshes
    local is_target = false
    for _, nm in ipairs(new_meshes) do
        if mesh == nm then
            is_target = true
            break
        end
    end

    if is_target then
        -- Allow moving
        mesh:setpackingoption('restriction', 'norestriction')
        -- Select it for user convenience
        mesh.selected = true
    else
        -- Lock others
        mesh:setpackingoption('restriction', 'locked')
        mesh.selected = false
    end
end

-- Create Packer
if tray.createpacker then
    local packer = tray:createpacker(tray.packingid_montecarlo)
    if packer then
        -- Configure Packer
        packer.packing_quality = -1 -- Default/Standard
        packer.z_limit = 0.0
        packer.start_from_current_positions = false -- Allow the new part to find any spot
        packer.minimaldistance = 2 -- 2mm spacing

        log("  Starting packing...")
        local errorcode = packer:pack()

        if errorcode == 0 then
            log("  Packing successful.")
        else
            log("  Packing finished with code: " .. tostring(errorcode))
        end
    else
        log("Error: Failed to create packer.")
    end
else
    log("Error: tray:createpacker not available.")
end

-- 4. Update UI
if application and application.triggerdesktopevent then
    application:triggerdesktopevent('updateparts')
end

log("--- Script Finished ---")
