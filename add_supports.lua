-- Add Supports Script
-- Runs a Netfabb support script (XML) on all meshes in the tray.

local support_xml_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\Hyrax 1.xml"
local log_file_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\netfabb_support_log.txt"

-- 1. Logging Setup
if system and system.logtofile then
    system:logtofile(log_file_path)
end

local function log(msg)
    if system and system.log then system:log(msg) end
    print(msg)
end

log("--- Start Add Supports Script ---")
log("XML Path: " .. support_xml_path)

if not tray or not tray.root then
    log("Error: tray or tray.root is not available.")
    return
end

-- 2. Helper to try method execution
local function try_apply_support(entity, name)
    local methods_to_try = {
        "runsupportscript",
        "runSupportScript",
        "RunSupportScript",
        "generate_support",
        "generateSupport"
    }

    local applied = false

    for _, method_name in ipairs(methods_to_try) do
        local method_exists = false
        pcall(function()
            if entity[method_name] then method_exists = true end
        end)

        if method_exists then
            log("Attempting method: " .. method_name .. " on " .. name)
            local ok, err = pcall(function()
                -- Assuming the method takes the path as the first argument
                entity[method_name](entity, support_xml_path)
            end)

            if ok then
                log("Success: Method " .. method_name .. " executed.")
                applied = true
                break
            else
                log("Failed: Method " .. method_name .. " raised error: " .. tostring(err))
            end
        end
    end

    if not applied then
        -- Try the createSupport / assignSupport workflow (common for TrayMesh objects)
        -- Reference: Script8_CreateSupport.lua
        log("Attempting createsupport/assignsupport workflow on " .. name)
        local ok_workflow, err_workflow = pcall(function()
             -- We expect entity to be a TrayMesh which has a .mesh property (LuaMesh)
             if entity.mesh then
                 local luamesh = entity.mesh
                 local matrix = entity.matrix

                 log("  Entity has .mesh property. Proceeding.")

                 -- Duplicate the mesh to avoid modifying the original during support calculation?
                 -- Script8 does: newMesh = luamesh:dupe(); newMesh:applymatrix(matrix);
                 -- This creates a world-space representation of the mesh to generate supports on.

                 local work_mesh = luamesh
                 if luamesh.dupe then
                    work_mesh = luamesh:dupe()
                 end

                 if matrix and work_mesh.applymatrix then
                    work_mesh:applymatrix(matrix)
                 end

                 log("  Generating support with XML: " .. support_xml_path)
                 -- createsupport is a method on LuaMesh
                 local support_obj = work_mesh:createsupport(support_xml_path)

                 if support_obj then
                     local tri_count = 0
                     pcall(function() tri_count = support_obj.trianglecount end)
                     log("  Support object created with " .. tostring(tri_count) .. " triangles.")

                     if tri_count == 0 then
                        log("Warning: Generated support has 0 triangles. It may not be visible.")
                     end

                     -- User requested to explicitly add the mesh to the tray to ensure visibility
                     log("  Adding support mesh to tray (tray.root:addmesh)...")
                     local ok_add, err_add = pcall(function()
                         if tray and tray.root and tray.root.addmesh then
                             tray.root:addmesh(support_obj)
                             log("  Success: Support mesh added to tray.")
                         elseif tray and tray.addmesh then
                             tray:addmesh(support_obj)
                             log("  Success: Support mesh added to tray via tray:addmesh.")
                         else
                             log("  Warning: neither tray.root.addmesh nor tray:addmesh available.")
                         end
                     end)
                     if not ok_add then
                         log("  Error adding support mesh to tray: " .. tostring(err_add))
                     end

                     log("  Assigning to entity...")
                     -- assignsupport is a method on TrayMesh (entity)
                     if entity.assignsupport then
                        entity:assignsupport(support_obj, false)

                        -- Force visibility and selection to ensure it is shown in GUI
                        pcall(function()
                            entity.selected = true
                            log("  Entity selected.")
                        end)
                        pcall(function()
                            entity.visible = true
                            log("  Entity visibility set to true.")
                        end)

                        log("Success: Support assigned via createsupport/assignsupport.")
                        applied = true -- Mark as applied if successful inside pcall
                     else
                        error("Entity lacks assignsupport method")
                     end
                 else
                     error("createsupport returned nil (check XML path?)")
                 end
             else
                 error("Entity does not have .mesh property")
             end
        end)

        if ok_workflow and applied then
            -- applied is already set to true inside pcall if successful
        elseif not ok_workflow then
            log("Failed: createsupport workflow error: " .. tostring(err_workflow))
        end
    end

    if not applied then
        -- Try system level calls if entity methods fail
        local system_has_method = false
        pcall(function()
            if system and system.runsupportscript then system_has_method = true end
        end)

        if system_has_method then
             log("Attempting system:runsupportscript on " .. name)
             local ok, err = pcall(function()
                system:runsupportscript(entity, support_xml_path)
             end)
             if ok then
                applied = true
                log("Success: system:runsupportscript executed.")
             else
                log("Failed: system:runsupportscript raised error: " .. tostring(err))
             end
        end
    end

    if not applied then
        log("Warning: Could not find or execute a support method for " .. name)

        log("--- Debugging Entity ---")
        -- Try to get metatable
        local mt = getmetatable(entity)
        if mt then
            log("Metatable found. Keys:")
            for k,v in pairs(mt) do
                log("  [MT] " .. tostring(k) .. ": " .. tostring(v))
                if type(v) == "table" and k == "__index" then
                     for k2,v2 in pairs(v) do
                        log("    [__index] " .. tostring(k2))
                     end
                end
            end
        else
            log("No metatable found.")
        end

        -- Try to inspect system global for support related functions
        log("--- Debugging System ---")
        if system then
            for k,v in pairs(system) do
                if type(k) == "string" and (string.find(string.lower(k), "support") or string.find(string.lower(k), "script")) then
                    log("  [System] " .. k .. ": " .. tostring(v))
                end
            end
        end
        
        -- Try to inspect global _G
        log("--- Debugging Globals ---")
        for k,v in pairs(_G) do
             if type(k) == "string" and (string.find(string.lower(k), "support") or string.find(string.lower(k), "netfabb")) then
                log("  [_G] " .. k .. ": " .. tostring(v))
             end
        end
    end
end

-- 3. Iterate Parts
-- Logic adapted from Part Rename New.lua to find all top-level items/meshes

local root = tray.root
local items_count = 0
local ok_count, c = pcall(function() return root.itemcount end)
if ok_count and c then items_count = c end

local found_parts = false

if items_count > 0 then
    log("Found " .. items_count .. " items in tray.")
    for i = 0, items_count - 1 do
        local ok_item, item = pcall(function() return root:getitem(i) end)
        if ok_item and item then
            local name = "Item " .. i
            local ok_name, n = pcall(function() return item.name end)
            if ok_name and n then name = n end

            -- Check if item has a mesh or is a mesh
            -- If it has a getmesh method, use that
            local mesh = nil
            if item.getmesh then
                -- Usually getmesh(0) gets the first mesh in the item
                local ok_m, m = pcall(function() return item:getmesh(0) end)
                if ok_m and m then
                    mesh = m
                end
            end

            -- If item itself is treated as mesh (sometimes happens in API nuances)
            if not mesh then
                local ok_tri, tri = pcall(function() return item.trianglecount end)
                if ok_tri and tri then
                    mesh = item
                end
            end

            if mesh then
                log("Processing " .. name)
                try_apply_support(mesh, name)
                found_parts = true
            else
                log("Skipping " .. name .. ": No mesh found.")
            end
        end
    end
else
    -- Fallback: iterate meshes directly if itemcount is 0 or failed
    log("No items found via itemcount. Checking meshcount...")
    local mesh_count = 0
    local ok_mc, mc = pcall(function() return root.meshcount end)
    if ok_mc and mc then mesh_count = mc end

    if mesh_count > 0 then
        for i = 0, mesh_count - 1 do
            local ok_m, m = pcall(function() return root:getmesh(i) end)
            if ok_m and m then
                local name = "Mesh " .. i
                try_apply_support(m, name)
                found_parts = true
            end
        end
    end
end

if not found_parts then
    log("No parts/meshes found to process.")
end

-- Update view
if application then
    log("Application object exists. Triggering updateparts...")
    if application.triggerdesktopevent then
        local ok_update, err_update = pcall(function() application:triggerdesktopevent('updateparts') end)
        if not ok_update then
            log("Error triggering updateparts: " .. tostring(err_update))
        end
    else
        log("application.triggerdesktopevent is missing.")
    end
else
    log("Application object missing. Cannot trigger updateparts.")
end

log("--- End Add Supports Script ---")
