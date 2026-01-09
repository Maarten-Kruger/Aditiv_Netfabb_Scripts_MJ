-- Diagnostic Script to find methods for duplicating TrayMesh with supports
-- Writes to a log file.

-- Determine log path (Use app data or temp if possible, fallback to hardcoded for specific user if needed)
local log_file_path = "C:\\Users\\Maarten\\OneDrive\\Desktop\\diagnostic_log.txt"

-- Setup logging once
if system and system.logtofile then
    pcall(function() system:logtofile(log_file_path) end)
end

-- Helper to log to file and console
local function log(msg)
    print(msg) -- To Netfabb console
    if system and system.log then
        system:log(msg)
    else
        -- Fallback if system.log is not active/redirected
        local f = io.open(log_file_path, "a")
        if f then
            f:write(msg .. "\n")
            f:close()
        end
    end
end

-- Helper to dump keys of an object/metatable
local function inspect_object(obj, name)
    log("--- Inspecting " .. name .. " ---")
    if not obj then
        log(name .. " is nil")
        return
    end

    local mt = getmetatable(obj)
    if not mt then
        log(name .. " has no metatable. Dumping direct keys (if any):")
        for k, v in pairs(obj) do
            log("  Key: " .. tostring(k) .. " (" .. type(v) .. ")")
        end
    else
        log(name .. " Metatable keys:")
        for k, v in pairs(mt) do
             if type(k) == "string" then
                log("  Key: " .. k .. " (" .. type(v) .. ")")
             end
        end
        if type(mt.__index) == "table" then
            log(name .. " Metatable.__index keys:")
            for k, v in pairs(mt.__index) do
                if type(k) == "string" then
                    log("  Key: " .. k .. " (" .. type(v) .. ")")
                end
            end
        end
    end
end

log("--- Diagnostic Script Started ---")

if not _G.netfabbtrayhandler then
    log("Error: netfabbtrayhandler not available.")
    return
end

local tray = netfabbtrayhandler:gettray(0)
if not tray then
    log("Error: No tray found.")
    return
end

local root = tray.root
if root.meshcount == 0 then
    log("Error: No meshes in the first tray. Please add a part with supports.")
    return
end

-- Get the first mesh
local traymesh = root:getmesh(0)
log("Target Mesh Name: " .. traymesh.name)

-- 1. Inspect TrayMesh methods
inspect_object(traymesh, "TrayMesh")

-- 2. Test createsupportedmesh
log("--- Testing createsupportedmesh ---")
if traymesh.createsupportedmesh then
    -- Param 1: mergepart (Boolean) - Keep original part? Yes (true)
    -- Param 2: mergeopensupport (Boolean) - Yes (true)
    -- Param 3: mergeclosedsupport (Boolean) - Yes (true)
    -- Param 4: openthickening (Number) - 0.0 or 0.1

    local status, result = pcall(function()
        return traymesh:createsupportedmesh(true, true, true, 0.1)
    end)

    if status then
        log("createsupportedmesh call succeeded.")
        log("Result type: " .. type(result))
        log("Result tostring: " .. tostring(result))

        if result then
            -- Check if it is a Mesh object we can add to the tray
            if result.facecount then
                log("Result appears to be a LuaMesh. Facecount: " .. result.facecount)

                -- Add to tray to visualize
                local new_tm = root:addmesh(result)
                new_tm.name = "CreatedSupportedMesh Result"
                log("Added result to tray as 'CreatedSupportedMesh Result'")

                -- Verify if supports are baked in (by volume/facecount comparison)
                if traymesh.mesh then
                     log("Original Facecount: " .. traymesh.mesh.facecount)
                end
                log("New Facecount: " .. result.facecount)

            elseif result.mesh then
                 log("Result appears to be a TrayMesh.")
            else
                 log("Result is unknown userdata.")
                 inspect_object(result, "ResultObject")
            end
        end
    else
        log("createsupportedmesh call failed: " .. tostring(result))
    end
else
    log("createsupportedmesh method NOT found on TrayMesh.")
end


log("--- Diagnostic Script Complete ---")
