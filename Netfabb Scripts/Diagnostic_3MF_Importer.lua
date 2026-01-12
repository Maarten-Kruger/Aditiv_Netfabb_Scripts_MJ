-- Diagnostic_3MF_Importer.lua
-- Diagnostic script to test 3MF import methods and support editability.

-- Standard Logging Setup
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Diagnostic_3MF_Importer ---")

-- 1. File Selection (Native Windows Dialog)
log("Opening file dialog...")
local file_path = system:showopendialog("*.3mf")

if not file_path or file_path == "" then
    log("No file selected. Exiting.")
    return
end

-- 2. Setup Logging to File
local log_file_path = file_path .. "_diagnostic_log.txt"

if system and system.logtofile then
    local ok, err = pcall(function() system:logtofile(log_file_path) end)
    if ok then
        log("Log file successfully set to: " .. log_file_path)
    else
        log("Failed to set log file: " .. tostring(err))
    end
end

log("Selected file: " .. file_path)

-- Helper to inspect system keys
log("Inspecting 'system' keys for '3mf'...")
local ok_keys, err_keys = pcall(function()
    for k, v in pairs(system) do
        if string.find(string.lower(k), "3mf") then
            log("Found system key: " .. k .. " (" .. type(v) .. ")")
        end
    end
end)

-- Helper: Check for supports on a mesh
local function check_support(mesh)
    local has_support = false
    local support_info = "None"

    local ok_supp, res_supp = pcall(function() return mesh.support end)
    if ok_supp and res_supp then
        has_support = true
        support_info = "Property .support exists"
        if type(res_supp) == 'table' or type(res_supp) == 'userdata' then
             support_info = support_info .. " (Type: " .. type(res_supp) .. ")"
        end
    else
        local ok_count, count = pcall(function() return mesh:getsupportcount() end)
        if ok_count then
             has_support = true
             support_info = "Method :getsupportcount() returns " .. tostring(count)
        end
    end
    return has_support, support_info
end

-- Helper: Inspect a table or userdata
local function inspect_object(obj, name)
    log("Inspecting " .. name .. " (" .. type(obj) .. "):")
    if type(obj) == 'table' then
        for k, v in pairs(obj) do
            if k ~= "mt" then
                log("  [" .. tostring(k) .. "] = " .. tostring(v) .. " (" .. type(v) .. ")")
            end
            if type(v) == 'userdata' then
                local ok_name, m_name = pcall(function() return v.name end)
                if ok_name then log("    -> Mesh Name: " .. tostring(m_name)) end
            end
        end
        -- Inspect wrapper metatable
        if obj.mt then
            log("  Wrapper .mt keys:")
            for k,v in pairs(obj.mt) do
                log("    " .. tostring(k))
            end
        end
    elseif type(obj) == 'userdata' then
        local mt = getmetatable(obj)
        if mt then
            log("  Metatable keys:")
            for k,v in pairs(mt) do
                log("    " .. tostring(k))
            end
        else
            log("  No accessible metatable.")
        end
    else
        log("  Not a table or userdata.")
    end
end

-- Helper: Add mesh to tray and process it
local function add_and_process_mesh(mesh, suffix)
    if type(mesh) ~= 'userdata' then return end

    -- Rename
    local old_name = "Unknown"
    pcall(function() old_name = mesh.name end)
    local new_name = old_name .. suffix
    pcall(function() mesh.name = new_name end)
    log("  Processed mesh: " .. old_name .. " -> " .. new_name)

    -- Add to tray (if not already there - hard to check, but addmesh is usually safe)
    if tray and tray.root then
        local ok_add, err_add = pcall(function() tray.root:addmesh(mesh) end)
        if ok_add then
            log("    Successfully added to tray.root")
        else
            log("    Failed to add to tray.root (or already added): " .. tostring(err_add))
        end
    else
        log("    Cannot add to tray: tray.root not available")
    end

    -- Check support
    local _, s_info = check_support(mesh)
    log("    Support info: " .. s_info)
end

-- Helper: Get current mesh count safely
local function get_mesh_count()
    if tray and tray.root then
        return tray.root.meshcount
    end
    return 0
end

-- Method 1: system:load3mf
log("--- Testing Method 1: system:load3mf ---")
local count_before_m1 = get_mesh_count()
local ok_m1, res_m1 = pcall(function() return system:load3mf(file_path) end)

if ok_m1 then
    log("Method 1 call returned success. Result type: " .. type(res_m1))
    inspect_object(res_m1, "load3mf_result")

    -- Check for new meshes in tray
    local count_after_m1 = get_mesh_count()
    if count_after_m1 > count_before_m1 then
        log("Method 1 added " .. (count_after_m1 - count_before_m1) .. " meshes to tray.")
        for i = count_before_m1, count_after_m1 - 1 do
            local m = tray.root:getmesh(i)
            add_and_process_mesh(m, "_load3mf")
        end
    else
        log("Method 1 did not add meshes directly to tray.")
        -- Fallback: try inspecting result if it was a table of meshes (unlikely given logs, but safe to keep)
        if type(res_m1) == 'table' then
            for k, v in pairs(res_m1) do
                 if type(v) == 'userdata' then add_and_process_mesh(v, "_load3mf") end
            end
        elseif type(res_m1) == 'userdata' then
            add_and_process_mesh(res_m1, "_load3mf")
        end
    end
else
    log("Method 1 failed: " .. tostring(res_m1))
end


-- Method 2: system:create3mfimporter
log("--- Testing Method 2: system:create3mfimporter ---")

-- Prepare parent group (4th argument)
local parent_group = nil
if tray and tray.root then parent_group = tray.root end

-- Try signatures based on errors/asserts
local signatures_to_try = {
    { args = {file_path}, name = "(path)" },
    { args = {file_path, true}, name = "(path, true)" },
    { args = {file_path, true, ""}, name = "(path, true, \"\")" },
    { args = {file_path, true, parent_group}, name = "(path, true, group)" }, -- simplified 3 args
    { args = {file_path, true, "", parent_group}, name = "(path, true, \"\", group)" } -- previous one that asserted
}

local importer = nil
for _, sig in ipairs(signatures_to_try) do
    if not importer then
        log("Trying create3mfimporter" .. sig.name .. "...")
        local ok_sig, res_sig = pcall(function()
            -- unpack not available in all Lua 5.1 environments safely for inner closures, manual dispatch
            if #sig.args == 1 then return system:create3mfimporter(sig.args[1])
            elseif #sig.args == 2 then return system:create3mfimporter(sig.args[1], sig.args[2])
            elseif #sig.args == 3 then return system:create3mfimporter(sig.args[1], sig.args[2], sig.args[3])
            elseif #sig.args == 4 then return system:create3mfimporter(sig.args[1], sig.args[2], sig.args[3], sig.args[4])
            end
        end)

        if ok_sig and res_sig then
            log("  Success!")
            importer = res_sig
        else
            log("  Failed: " .. tostring(res_sig))
        end
    end
end

if importer then
    log("system:create3mfimporter returned object.")
    inspect_object(importer, "3mf_importer_obj")

    -- Check properties
    local ok_count, count = pcall(function() return importer.meshcount end)
    if ok_count then
        log("importer.meshcount = " .. tostring(count))

        local start_idx = 0
        local end_idx = count
        if count == 0 then end_idx = 1 end

        for i = start_idx, end_idx do
            local ok_mesh, mesh = pcall(function() return importer:getmesh(i) end)
            if ok_mesh and mesh then
                log("getmesh(" .. i .. ") returned mesh.")
                add_and_process_mesh(mesh, "_importer")
            end
        end
    else
        log("Could not read importer.meshcount")
    end
else
    log("All create3mfimporter signatures failed.")
end


-- Method 3: system:createcadimport
log("--- Testing Method 3: system:createcadimport ---")

local ok_cad, importer_cad = pcall(function() return system:createcadimport(0) end)

if ok_cad and importer_cad then
    log("system:createcadimport(0) returned object.")
    inspect_object(importer_cad, "cad_importer_obj")

    -- Step 3a: Add File
    log("Attempting importer_cad:addfile(path)...")
    local ok_add, res_add = pcall(function() return importer_cad:addfile(file_path) end)

    if ok_add then
        log("  addfile success.")

        -- Step 3b: createmesh (all entities)
        log("Attempting importer_cad:createmesh()...")
        local ok_cm, mesh_cm = pcall(function() return importer_cad:createmesh() end)
        if ok_cm and mesh_cm then
            log("  createmesh success.")
            add_and_process_mesh(mesh_cm, "_cadimport_all")
        else
            log("  createmesh failed: " .. tostring(mesh_cm))
        end

        -- Step 3c: createsinglemesh (iterate entities)
        -- We don't have 'entitycount' property confirmed, so we probe indices 0-10
        log("Attempting createsinglemesh loop (0-10)...")
        for i = 0, 10 do
            local ok_name, name = pcall(function() return importer_cad:getentityname(i) end)
            if ok_name and name and name ~= "" then
                log("  Entity " .. i .. ": " .. tostring(name))

                local ok_sm, mesh_sm = pcall(function() return importer_cad:createsinglemesh(i) end)
                if ok_sm and mesh_sm then
                    add_and_process_mesh(mesh_sm, "_cadimport_ent" .. i)
                else
                    log("    createsinglemesh failed.")
                end
            end
        end

    else
        log("  addfile failed: " .. tostring(res_add))
    end
else
    log("createcadimport failed: " .. tostring(importer_cad))
end

-- Finalize
pcall(function() application:triggerdesktopevent('updateparts') end)
log("--- End of Diagnostic ---")
pcall(function() system:messagebox("Diagnostic Complete.\nLog: " .. log_file_path) end)
