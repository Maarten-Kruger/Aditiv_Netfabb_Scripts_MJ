-- Diagnostic_STEP_Importer.lua
-- Diagnostic script to test STEP import with variable accuracy settings.

-- Standard Logging Function
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- Safely get tray
local function get_tray()
    if netfabbtrayhandler then
        -- Attempt to get the first tray
        local ok, t = pcall(function() return netfabbtrayhandler:gettray(0) end)
        if ok and t then return t end
    end
    if tray then
        return tray
    end
    return nil
end

log("--- Starting Diagnostic_STEP_Importer ---")

-- 1. File Selection
local ok_dlg, file_path = pcall(function() return system:showopendialog("*.stp;*.step") end)
if not ok_dlg or not file_path or file_path == "" then
    log("No file selected or dialog failed. Exiting.")
    -- Attempt to notify user
    pcall(function() system:inputdlg("No file selected.", "Error", "OK") end)
    return
end

-- 2. Setup Logging
local log_file_path = file_path .. "_diagnostic_log.txt"
if system and system.logtofile then
    pcall(function() system:logtofile(log_file_path) end)
end
log("Selected file: " .. file_path)

-- 3. Parameter Input
local default_val = "SWEEP"
local ok_input, user_input = pcall(function()
    return system:inputdlg("Enter Tolerance (e.g. 0.1) or 'SWEEP':", "Import Settings", default_val)
end)

if not ok_input or not user_input or user_input == "" then
    log("No input provided. Defaulting to SWEEP.")
    user_input = "SWEEP"
end

local mode = "SINGLE"
local tolerances = {}

if string.upper(user_input) == "SWEEP" then
    mode = "SWEEP"
    tolerances = {0.001, 0.01, 0.1, 0.5, 1.0, 5.0}
    log("Mode: SWEEP (Values: " .. table.concat(tolerances, ", ") .. ")")
else
    mode = "SINGLE"
    local val = tonumber(user_input)
    if val then
        tolerances = {val}
        log("Mode: SINGLE (Value: " .. val .. ")")
    else
        log("Invalid number input '"..user_input.."'. Defaulting to SWEEP.")
        mode = "SWEEP"
        tolerances = {0.001, 0.01, 0.1, 0.5, 1.0, 5.0}
    end
end

-- 4. Import Logic
local function test_import(path, tol)
    log("Testing Import with Tolerance: " .. tol)

    local ok, importer = pcall(function() return system:createcadimport(0) end)
    if not ok or not importer then
        log("  Failed to create CAD importer.")
        return nil
    end

    -- loadmodel(filename, accuracy)
    -- Using the 2-argument version (path, accuracy) as seen in BaseRoutines.lua
    local ok_load, model = pcall(function() return importer:loadmodel(path, tol) end)

    if not ok_load then
        log("  loadmodel call failed (Runtime Error).")
        return nil
    end

    if not model then
        log("  loadmodel returned nil.")
        return nil
    end

    local entity_count = 0
    pcall(function() entity_count = model.entitycount end)
    log("  Model loaded. Entity Count: " .. entity_count)

    if entity_count == 0 then
        return nil
    end

    local meshes = {}
    local total_tris = 0
    local total_verts = 0

    for i = 0, entity_count - 1 do
        local ok_mesh, mesh = pcall(function() return model:createsinglemesh(i) end)
        if ok_mesh and mesh then
            table.insert(meshes, mesh)
            pcall(function()
                total_tris = total_tris + mesh.trianglecount
                total_verts = total_verts + mesh.vertexcount
            end)
        end
    end

    log("  Import Success. Meshes: " .. #meshes .. ", Tris: " .. total_tris .. ", Verts: " .. total_verts)
    return meshes, total_tris, total_verts
end

-- 5. Execution Loop
local tray = get_tray()
local root = nil
if tray then
    root = tray.root
else
    log("Warning: No active tray found. Meshes will not be added to the scene.")
end

log("--- Starting Import Tests ---")

for _, tol in ipairs(tolerances) do
    local meshes, tris, verts = test_import(file_path, tol)

    if meshes and root then
        -- Add to tray
        for i, mesh in ipairs(meshes) do
            local ok_add, new_mesh_item = pcall(function() return root:addmesh(mesh) end)
            if ok_add and new_mesh_item then
                local suffix = "_Tol_" .. tol
                if #meshes > 1 then suffix = suffix .. "_" .. i end
                -- Rename
                local safe_name = "Part" .. suffix
                pcall(function() new_mesh_item.name = safe_name end)
            else
                log("  Failed to add mesh to tray.")
            end
        end
    end
end

log("--- Diagnostic Complete ---")
pcall(function() system:inputdlg("Diagnostic Complete. Check log: " .. log_file_path, "Done", "OK") end)
