-- Diagnostic_3MF_Importer.lua
-- Diagnostic script to test 3MF import methods and support editability.
-- Updates: Added system:importfile test (Test 3) and retained previous tests.

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Diagnostic_3MF_Importer (importfile Focus) ---")

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

-- TEST 1: system:load3mf (Baseline)
log("--- Test 1: system:load3mf (Baseline) ---")
local ok1, res1 = pcall(function() return system:load3mf(file_path) end)
if ok1 then
    log("load3mf success. Result type: " .. type(res1))
else
    log("load3mf failed: " .. tostring(res1))
end


-- TEST 2: system:loadfabbproject
log("--- Test 2: system:loadfabbproject ---")
local ok_proj, proj_obj = pcall(function() return system:loadfabbproject(file_path) end)
if ok_proj then
    log("loadfabbproject success. Result type: " .. type(proj_obj))
else
    log("loadfabbproject failed: " .. tostring(proj_obj))
end


-- TEST 3: system:importfile (User Requested)
log("--- Test 3: system:importfile ---")
log("Calling system:importfile('" .. file_path .. "')...")

local ok_imp, importedParts = pcall(function() return system:importfile(file_path) end)

if ok_imp then
    if importedParts then
        log("system:importfile returned success. Type: " .. type(importedParts))

        -- Handle table (array of meshes)
        if type(importedParts) == 'table' then
            log("Result is a table. Count: " .. (#importedParts or "unknown"))

            for i, trayMesh in ipairs(importedParts) do
                -- Inspect Mesh Name
                local mesh_name = "Unknown"
                pcall(function() mesh_name = trayMesh.name end)
                log("Part " .. i .. " Name: " .. mesh_name)

                -- Inspect Volume (using getvolume as requested, wrapping in pcall)
                local vol = "N/A"
                local ok_vol, v = pcall(function() return trayMesh:getvolume() end)
                if ok_vol then vol = tostring(v) .. " mm^3" end
                log("Volume: " .. vol)

                -- Check .issupport
                local is_supp = false
                local ok_is, val_is = pcall(function() return trayMesh.issupport end)

                if ok_is and val_is then
                    log("Status: Recognized as SUPPORT (via .issupport property)")
                    is_supp = true
                else
                    -- Name check fallback
                    if string.find(string.lower(mesh_name), "support") then
                        log("Status: Manually identifying as SUPPORT (via Name check)...")
                        local ok_set, err_set = pcall(function() trayMesh.issupport = true end)
                        if ok_set then
                            log("  Set .issupport = true: Success")
                        else
                            log("  Set .issupport = true: Failed (" .. tostring(err_set) .. ")")
                        end
                    else
                         log("Status: Standard Mesh")
                    end
                end

                -- Add to tray if not implicitly added?
                -- Usually importfile adds them. Let's log if they are in tray.
                -- We won't explicitly add them to avoid duplication if importfile does it.
            end
        else
            log("Result is not a table (" .. type(importedParts) .. ").")
        end
    else
        log("system:importfile returned nil.")
    end
else
    log("system:importfile failed (Runtime Error): " .. tostring(importedParts))
end

log("--- Diagnostic Complete ---")
pcall(function() system:messagebox("Check Log: " .. log_file_path) end)
