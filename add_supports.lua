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

        -- Last ditch effort: list methods available on entity for debugging
        log("  Available keys on entity:")
        local ok_pairs, err_pairs = pcall(function()
             for k,v in pairs(entity) do
                 -- Only log string keys to avoid clutter/errors
                 if type(k) == "string" then
                    -- log("    " .. k) -- Uncomment if deep debugging is needed
                 end
             end
        end)
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
if application and application.triggerdesktopevent then
    pcall(function() application:triggerdesktopevent('updateparts') end)
end

log("--- End Add Supports Script ---")
