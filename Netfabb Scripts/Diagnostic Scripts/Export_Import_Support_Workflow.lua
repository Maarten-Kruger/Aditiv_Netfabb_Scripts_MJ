-- Export_Import_Support_Workflow.lua
-- Diagnostic Workflow: Export Part and Support separately, Import with Split, Re-assign.

local function log(msg)
    if system and system.log then system:log(msg) end
end

log("--- Starting Export_Import_Support_Workflow ---")

-- 1. Setup Logging
-- Fixed: Removed os.getenv dependency which caused runtime errors.
local log_file = "C:\\SupportWorkflow_Log.txt"
if system.logtofile then pcall(function() system:logtofile(log_file) end) end
log("Log file: " .. log_file)

-- 2. Identify Selection
local tray = nil
if _G.tray then tray = _G.tray end
if not tray and _G.netfabbtrayhandler then tray = netfabbtrayhandler:gettray(0) end

if not tray or not tray.root then
    log("Error: No active tray found.")
    return
end

-- Find selected mesh or just take the first one
local target_mesh = nil
if tray.root.meshcount > 0 then
    -- Check selection
    for i = 0, tray.root.meshcount - 1 do
        local m = tray.root:getmesh(i)
        if m.selected then
            target_mesh = m
            break
        end
    end
    -- Fallback to first mesh
    if not target_mesh then target_mesh = tray.root:getmesh(0) end
end

if not target_mesh then
    log("Error: No mesh found in tray.")
    return
end

log("Target Mesh: " .. target_mesh.name)

-- Check for supports
local has_support = false
local support_obj = nil
local ok_sup, res_sup = pcall(function() return target_mesh.support end)
if ok_sup and res_sup then
    has_support = true
    support_obj = res_sup
    log("Support found (property access).")
else
    local ok_c, count = pcall(function() return target_mesh:getsupportcount() end)
    if ok_c and count > 0 then
        has_support = true
        log("Support found (count="..count..").")
        -- If property didn't work, we might not have the object easily.
        -- We will try createsupportedmesh splitting below.
    end
end

if not has_support then
    log("Error: Target mesh has no supports. Please add support first.")
    return
end


-- 3. Separate Support as Mesh
log("Step: Separating Support into Mesh...")
local part_mesh_geo = nil
local support_mesh_geo = nil

-- Approach: createsupportedmesh -> check result
-- The API createsupportedmesh usually returns a MERGED mesh if (true, true, true)
-- We want separate.
-- Try: createsupportedmesh(true, false, false) -> Part only?
-- Try: createsupportedmesh(false, true, true) -> Support only?

local ok_part, res_part = pcall(function()
    return target_mesh:createsupportedmesh(true, false, false, 0.0)
end)
if ok_part and res_part then
    part_mesh_geo = res_part.mesh
    log("  Extracted Part Geometry.")
end

local ok_supp_geo, res_supp_geo = pcall(function()
    -- (mergepart=false, mergeopen=true, mergeclosed=true)
    return target_mesh:createsupportedmesh(false, true, true, 0.0)
end)
if ok_supp_geo and res_supp_geo then
    support_mesh_geo = res_supp_geo.mesh
    log("  Extracted Support Geometry.")
end

if not part_mesh_geo or not support_mesh_geo then
    log("Error: Failed to split part and support geometries.")
    return
end


-- 4. Export to 3MF
log("Step: Exporting to 3MF...")
-- Fixed: Removed os.getenv
local export_path = "C:\\SplitSupportExport.3mf"
local ok_exp, exporter = pcall(function() return system:create3mfexporter() end)

if ok_exp and exporter then
    -- Add Part
    local entry_p = exporter:add(part_mesh_geo)
    entry_p.name = "OriginalPart"
    entry_p.grouppath = "Production/Parts"

    -- Add Support (as regular mesh)
    local entry_s = exporter:add(support_mesh_geo)
    entry_s.name = "SupportAsMesh"
    entry_s.grouppath = "Production/Supports"

    -- Export
    exporter:exporttofile(export_path)
    log("  Exported to: " .. export_path)
else
    log("Error: Failed to create exporter.")
    return
end


-- 5. Import with Split Meshes
log("Step: Importing with create3mfimporter (split=true)...")
local ok_imp, importer = pcall(function()
    -- (path, split_meshes=true, name, tray)
    return system:create3mfimporter(export_path, true, "ImportedGroup", tray)
end)

if ok_imp and importer then
    local count = importer.meshcount
    log("  Importer found " .. count .. " meshes.")

    local imported_part = nil
    local imported_support = nil

    for i = 0, count - 1 do
        local m = importer:getmesh(i)
        if m then
            -- Identify by name
            local m_name = m.name
            log("    Mesh " .. i .. ": " .. m_name)

            -- Add to tray to work with it
            local tm = tray.root:addmesh(m)
            tm.name = "Imp_" .. m_name -- Rename to track

            if string.find(m_name, "OriginalPart") then
                imported_part = tm
            elseif string.find(m_name, "SupportAsMesh") then
                imported_support = tm
            end
        end
    end

    -- 6. Re-assign Support
    if imported_part and imported_support then
        log("Step: Re-assigning support...")

        -- Try assignsupport
        local ok_as, err_as = pcall(function()
            -- assignsupport(support_mesh, use_relative_coords?)
            -- If false (absolute), it uses world coords.
            return imported_part:assignsupport(imported_support, false)
        end)

        if ok_as then
            log("  Success: Support assigned to part.")

            -- Verify
            if imported_part.hassupport then
                log("  Verification: Part now has support attached.")
                -- Optional: Remove the separate support mesh now that it's attached
                tray.root:removemesh(imported_support)
                log("  Cleanup: Removed standalone support mesh.")
            else
                 log("  Verification Failed: .hassupport is false.")
            end
        else
            log("  Failure: assignsupport error: " .. tostring(err_as))
        end

    else
        log("Error: Could not identify both part and support meshes from import.")
    end

else
    log("Error: Import failed.")
end

pcall(function() application:triggerdesktopevent('updateparts') end)
log("--- Workflow Complete ---")
pcall(function() system:messagebox("Workflow Complete. Check Log.") end)
