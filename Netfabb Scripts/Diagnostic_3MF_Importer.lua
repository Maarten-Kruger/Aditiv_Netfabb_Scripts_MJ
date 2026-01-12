-- Diagnostic_3MF_Importer.lua
-- Diagnostic script to test 3MF import methods and support editability.
-- Focused on system:create3mfimporter as requested.

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Diagnostic_3MF_Importer (Focused) ---")

-- 1. File Selection
log("Opening file dialog...")
local file_path = system:showopendialog("*.3mf")

if not file_path or file_path == "" then
    log("No file selected. Exiting.")
    return
end

-- 2. Setup Logging
local log_file_path = file_path .. "_diagnostic_log.txt"
if system and system.logtofile then
    pcall(function() system:logtofile(log_file_path) end)
end
log("Selected file: " .. file_path)

-- Helper: Inspect support
local function check_support(mesh)
    local has_support = false
    local support_info = "None"

    -- Check .support property
    local ok_supp, res_supp = pcall(function() return mesh.support end)
    if ok_supp and res_supp then
        has_support = true
        support_info = "Property .support exists (Type: " .. type(res_supp) .. ")"

        -- Inspect support object if possible
        if type(res_supp) == 'userdata' or type(res_supp) == 'table' then
             local ok_vol, vol = pcall(function() return res_supp.volume end)
             if ok_vol then support_info = support_info .. ", Volume: " .. tostring(vol) end

             local ok_tc, tc = pcall(function() return res_supp.trianglecount end)
             if ok_tc then support_info = support_info .. ", Triangles: " .. tostring(tc) end
        end
    else
        -- Fallback: check getsupportcount
        local ok_count, count = pcall(function() return mesh:getsupportcount() end)
        if ok_count and count and count > 0 then
             has_support = true
             support_info = "Method :getsupportcount() returns " .. tostring(count)
        end
    end
    return has_support, support_info
end

-- Helper: Process Mesh
local function add_and_process_mesh(mesh, suffix)
    -- Relaxed type check: accept table wrappers
    if type(mesh) ~= 'userdata' and type(mesh) ~= 'table' then
        log("  Skipping mesh processing: Invalid type (" .. type(mesh) .. ")")
        return nil
    end

    local name = "Unknown"
    pcall(function() name = mesh.name end)

    -- Rename
    local new_name = name .. suffix
    pcall(function() mesh.name = new_name end)
    log("  Processed mesh: " .. name .. " -> " .. new_name)

    -- Add to tray
    local added = false
    if tray then
        if tray.root then
            local ok = pcall(function() tray.root:addmesh(mesh) end)
            if ok then added = true; log("    Added via tray.root:addmesh") end
        end
        if not added then
            local ok = pcall(function() tray:addmesh(mesh) end)
            if ok then added = true; log("    Added via tray:addmesh") end
        end
    end

    if not added then log("    Warning: Failed to add mesh to tray.") end

    -- Check Supports
    local has_sup, sup_info = check_support(mesh)
    log("    Support Status: " .. sup_info)

    return mesh
end

-- Method 2: system:create3mfimporter
log("--- Testing Method 2: system:create3mfimporter ---")

local tray_obj = tray

-- Trying the specific signature that worked
-- system:create3mfimporter(path, split_meshes, name, tray)
log("Calling system:create3mfimporter('" .. file_path .. "', true, 'ImportedPart', tray)...")

local ok, importer = pcall(function()
    return system:create3mfimporter(file_path, true, "ImportedPart", tray_obj)
end)

if ok and importer then
    log("Importer object created. Type: " .. type(importer))

    local ok_c, count = pcall(function() return importer.meshcount end)
    if not ok_c then count = 0; log("Failed to read meshcount.") end

    log("importer.meshcount = " .. tostring(count))

    local imported_meshes = {}

    -- Iterate meshes (0-based)
    -- If count is 0, we do nothing. If count is 1, index 0.
    for i = 0, count - 1 do
        log("Retrieving mesh " .. i .. "...")
        local ok_m, mesh = pcall(function() return importer:getmesh(i) end)
        if ok_m and mesh then
            log("  Got mesh object (Type: " .. type(mesh) .. ")")
            local p_mesh = add_and_process_mesh(mesh, "_imp_" .. i)
            if p_mesh then table.insert(imported_meshes, p_mesh) end
        else
            log("  Failed to get mesh " .. i)
        end
    end

    -- Logic for Support Assignment Probe
    if #imported_meshes >= 2 then
        log("Multiple meshes imported (".. #imported_meshes .."). Probing manual support assignment...")
        local main = imported_meshes[1] -- First mesh usually part
        local supp = imported_meshes[2] -- Second mesh usually support

        log("  Attempting to assign '" .. supp.name .. "' as support for '" .. main.name .. "'...")

        -- Probe 1: assignsupport(mesh)
        local ok_as, res_as = pcall(function() return main:assignsupport(supp) end)
        if ok_as then
            log("    assignsupport(mesh): Success!")
        else
            log("    assignsupport(mesh): Failed - " .. tostring(res_as))

            -- Probe 2: assignsupport(mesh, false)
            local ok_as2, res_as2 = pcall(function() return main:assignsupport(supp, false) end)
            if ok_as2 then
                log("    assignsupport(mesh, false): Success!")
            else
                log("    assignsupport(mesh, false): Failed - " .. tostring(res_as2))
            end
        end

    elseif #imported_meshes == 1 then
        log("Single mesh imported. It should contain supports if the 3MF had them.")
        -- The check_support in add_and_process_mesh already logged this.
        -- If support is missing here, it means create3mfimporter didn't load it or merged it non-parametrically.

    else
        log("No meshes imported.")
    end

else
    log("create3mfimporter call failed: " .. tostring(importer))
end

pcall(function() application:triggerdesktopevent('updateparts') end)
log("--- Diagnostic Complete ---")
pcall(function() system:messagebox("Check Log: " .. log_file_path) end)
