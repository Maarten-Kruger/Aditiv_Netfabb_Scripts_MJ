-- Diagnostic_3MF_Importer.lua
-- Diagnostic script to test 3MF import using system:load3mf as requested.

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Diagnostic_3MF_Importer (load3mf Focus) ---")

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
    local ok_name, n = pcall(function() return mesh.name end)
    if ok_name then name = n end

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

-- Method: system:load3mf
log("--- Testing Method: system:load3mf ---")
log("Calling system:load3mf('" .. file_path .. "')...")

local ok, result = pcall(function()
    return system:load3mf(file_path)
end)

if ok then
    log("Call successful. Result type: " .. type(result))

    if not result then
        log("Result is nil. Import failed.")
    elseif type(result) == 'userdata' or type(result) == 'table' then
        -- 1. Try to treat it as a single mesh
        local is_mesh = false
        local ok_vol, vol = pcall(function() return result.volume end)
        if ok_vol then
            is_mesh = true
            log("Result has .volume ("..tostring(vol).."). Treating as Single Mesh.")
            add_and_process_mesh(result, "_load3mf")
        end

        -- 2. Try to treat it as a Group (if not a mesh, or even if it is?)
        if not is_mesh then
            log("Result does not appear to be a single mesh (no volume). Checking if Group/List...")

            -- Check for numerical indexing (List)
            if result[1] or result[0] then
                log("Result has numerical index. Iterating as List...")
                for k, v in pairs(result) do
                    if type(v) == 'userdata' or type(v) == 'table' then
                        add_and_process_mesh(v, "_load3mf_idx" .. k)
                    end
                end

            -- Check for child interface (Group)
            elseif result.count or result.childcount then
                local count = result.count or result.childcount
                log("Result looks like a Group (count="..tostring(count)..")")
                -- Usually groups in Netfabb use :getchild(i)
                for i = 0, count - 1 do -- Assuming 0-based
                    local ok_c, child = pcall(function() return result:getchild(i) end)
                    if ok_c and child then
                        add_and_process_mesh(child, "_load3mf_child" .. i)
                    end
                end
            else
                log("Result structure is unclear. Inspecting keys:")
                for k, v in pairs(result) do
                    if k ~= "mt" then
                         log("  ["..tostring(k).."] ("..type(v)..")")
                    end
                end
                -- Last ditch: Try to add the object itself to tray anyway
                add_and_process_mesh(result, "_load3mf_raw")
            end
        end
    end
else
    log("system:load3mf call failed: " .. tostring(result))
end

pcall(function() application:triggerdesktopevent('updateparts') end)
log("--- Diagnostic Complete ---")
pcall(function() system:messagebox("Check Log: " .. log_file_path) end)
