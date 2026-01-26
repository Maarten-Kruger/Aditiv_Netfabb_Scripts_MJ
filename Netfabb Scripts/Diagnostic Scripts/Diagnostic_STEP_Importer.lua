-- Diagnostic_STEP_Importer.lua
-- Diagnostic tool to test STEP import capabilities and tolerances
-- Tests Importer Indices 0-10 with various Syntax combinations

-- 1. Setup Logging
local log_file_path = system:showsavefiledialog("Save Diagnostic Log As", "Text Files (*.txt)|*.txt", "STEP_Diagnostic_Log.txt")
if log_file_path and log_file_path ~= "" then
    pcall(function() system:logtofile(log_file_path) end)
end

local function log(msg)
    pcall(function() system:log(msg) end)
end

log("Starting STEP Import Diagnostic Script")
log("Time: " .. os.date("%Y-%m-%d %H:%M:%S"))

-- 2. Select File
local path = system:showopenfiledialog('Select STEP file', '*.stp;*.step')
if not path or path == "" then
    log("User cancelled file selection.")
    return
end

log("Selected file: " .. path)

-- 3. Configuration
local angle_tolerance = 20 -- Degrees
local deviations = {0.1, 0.01} -- mm
local edge_lengths = {0, 5, 1000} -- mm
local detail_levels = {3, 4, 5} -- 1-5 Scale

-- 4. Diagnostic Loop
for i = 0, 10 do
    log("--------------------------------------------------")
    log("Testing Importer Index: " .. i)

    -- Corrected pcall syntax: wrap method call in anonymous function
    local status, importer = pcall(function() return system:createcadimporter(i) end)

    if not status then
        log("  [CRITICAL] Failed to call system:createcadimporter(" .. i .. "). Error: " .. tostring(importer))
    elseif not importer then
        log("  [FAILURE] system:createcadimporter(" .. i .. ") returned nil.")
    else
        log("  [SUCCESS] Importer created.")

        -- Test Syntax 1: loadmodel(filename, surface_dev, angle_tol, max_edge_len)
        log("  --- Testing Syntax 1: (path, dev, angle, edge) ---")
        for _, dev in ipairs(deviations) do
            for _, edge in ipairs(edge_lengths) do
                log("    Params: Dev=" .. dev .. ", Angle=" .. angle_tolerance .. ", Edge=" .. edge)

                local t0 = os.clock()
                local load_status, model = pcall(function()
                    return importer:loadmodel(path, dev, angle_tolerance, edge)
                end)
                local t1 = os.clock()

                if load_status and model then
                    log("      [SUCCESS] Model loaded in " .. string.format("%.4f", t1-t0) .. "s")

                    local count_status, count = pcall(function() return model:getmeshcount() end)
                    if count_status then
                        log("      Mesh Count: " .. tostring(count))
                    else
                        log("      Could not get mesh count.")
                    end
                else
                    log("      [FAILED] Error: " .. tostring(model))
                end
            end
        end

        -- Test Syntax 2: loadmodel(filename, detaillevel)
        log("  --- Testing Syntax 2: (path, detail_level) ---")
        for _, detail in ipairs(detail_levels) do
            log("    Params: DetailLevel=" .. detail)

            local t0 = os.clock()
            local load_status, model = pcall(function()
                return importer:loadmodel(path, detail)
            end)
            local t1 = os.clock()
             if load_status and model then
                log("      [SUCCESS] Model loaded in " .. string.format("%.4f", t1-t0) .. "s")
                 local count_status, count = pcall(function() return model:getmeshcount() end)
                    if count_status then
                        log("      Mesh Count: " .. tostring(count))
                    else
                        log("      Could not get mesh count.")
                    end
            else
                 log("      [FAILED] Error: " .. tostring(model))
            end
        end
    end
end

log("Diagnostic Complete.")
pcall(function() system:inputdlg("Diagnostic Complete. Log saved to: " .. tostring(log_file_path), "Done") end)
