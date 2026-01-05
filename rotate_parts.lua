-- Script to rotate all parts 90 degrees horizontally
-- Units: Degrees (Assuming standard Netfabb behavior despite some doc ambiguity)
-- Axis: Z axis for horizontal rotation

local function rotate_group(group)
    if group == nil then return end

    -- Rotate meshes in this group
    local mesh_count = group.meshcount
    for i = 0, mesh_count - 1 do
        local part = group:getmesh(i)
        if part then
            -- Rotate 90 degrees around Z axis (0, 0, 1)
            -- part:rotate(axis_x, axis_y, axis_z, angle_degrees)
            part:rotate(0, 0, 1, 90)
            system:log("Rotated part: " .. part.name)
        end
    end

    -- Process subgroups (recursive)
    -- Using subgroupcount if available, or iterating safely
    if group.subgroupcount then
        local subgroup_count = group.subgroupcount
        for i = 0, subgroup_count - 1 do
            local subgroup = group:getsubgroup(i)
            if subgroup then
                rotate_group(subgroup)
            end
        end
    end
end

local function rotate_all_parts()
    -- Check if tray is available
    if tray == nil then
        system:log("Error: 'tray' variable is not available.")
        return
    end

    -- Try to get the root group
    local root = tray.root
    if root then
        system:log("Starting rotation on tray root.")
        rotate_group(root)
    else
        system:log("Error: Could not access tray.root")
    end

    system:log("Rotation complete.")

    -- Refresh the view if needed.
    if application and application.triggerdesktopevent then
        application:triggerdesktopevent('updateparts')
    end
end

if system and system.log then
    system:log("Starting rotation script")
end

rotate_all_parts()
