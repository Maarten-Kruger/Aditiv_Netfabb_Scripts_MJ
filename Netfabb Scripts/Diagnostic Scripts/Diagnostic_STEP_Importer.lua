-- Diagnostic_STEP_Importer.lua
-- Unified Diagnostic and Workflow Tool for STEP Import
-- Merges functionality of previous Diagnostic and Workflow scripts.
-- Fixes API call to system:createcadimport and ensures robust loadmodel syntax.
-- Fixes "invalid object method: showsavefiledialog" by using robust directory selection.
-- Fixes "attempt to index global 'os'" by removing restricted library calls.
-- Fixes "invalid object field: onclick" by passing function name string.

-- --- Logging Setup ---
local function log(msg)
    pcall(function() system:log(msg) end)
end

-- Robust Directory Selection (adapted from Part_Rename_MJ.lua)
local log_path = "C:\\Users\\Public\\Documents\\"
local default_filename = "STEP_Unified_Log.txt"
local log_file_full_path = ""

local ok_input, input_path = false, nil
local title = "Select Log Folder"

-- Try with 3 arguments (Title, DefaultPath, ShowNewFolderButton)
ok_input, input_path = pcall(function() return system:showdirectoryselectdialog(title, log_path, true) end)

-- Retry with 2 arguments if failed (API variation)
if not ok_input then
    ok_input, input_path = pcall(function() return system:showdirectoryselectdialog(title, log_path) end)
end

-- Fallback to system:inputdlg if still failed (Function missing or broken)
if not ok_input then
    ok_input, input_path = pcall(function() return system:inputdlg(title, title, log_path) end)
end

if ok_input and input_path and input_path ~= "" then
    -- Cleanup path
    local clean_path = string.gsub(input_path, '"', '')
    if string.sub(clean_path, -1) ~= "\\" then
        clean_path = clean_path .. "\\"
    end
    log_file_full_path = clean_path .. default_filename
else
    log("No directory selected or dialog failed. Using default.")
    log_file_full_path = log_path .. default_filename
end

-- Initialize Log File
if log_file_full_path and log_file_full_path ~= "" then
    local ok_log, err_log = pcall(function() system:logtofile(log_file_full_path) end)
    if not ok_log then
         -- Try fallback path if permission error or similar
         log_file_full_path = "C:\\" .. default_filename
         pcall(function() system:logtofile(log_file_full_path) end)
    end
end

log("--- Starting Unified STEP Importer Diagnostic ---")
-- Removed os.date as os library is restricted
log("Log file: " .. log_file_full_path)

-- --- Global Variables ---
maindialog = nil -- Must be global or accessible
edit_tolerance = nil
last_error = ""

-- --- Core Logic ---

-- 1. Diagnostic Scan Logic
function run_diagnostic_scan(path)
    log("Starting Diagnostic Scan on: " .. path)

    local deviations = {0.1, 0.01} -- mm
    local edge_lengths = {0, 5, 1000} -- mm
    local angle_tolerance = 20 -- Degrees
    local detail_levels = {3, 4, 5} -- 1-5 Scale

    for i = 0, 10 do
        log("--------------------------------------------------")
        log("Testing Importer Index: " .. i)

        -- Fix: Use system:createcadimport (not createcadimporter)
        local status, importer = pcall(function() return system:createcadimport(i) end)

        if not status then
            log("  [CRITICAL] Failed to call system:createcadimport(" .. i .. "). Error: " .. tostring(importer))
        elseif not importer then
            log("  [FAILURE] system:createcadimport(" .. i .. ") returned nil.")
        else
            log("  [SUCCESS] Importer created.")

            -- Test Syntax 1: loadmodel(path, deviation, angle_tol, max_edge_len)
            -- Matches user provided image: loadmodel('file.step', 0.1, 20, 5)
            log("  --- Testing Syntax 1: (path, dev, angle, edge) ---")
            for _, dev in ipairs(deviations) do
                for _, edge in ipairs(edge_lengths) do
                    log("    Params: Dev=" .. dev .. ", Angle=" .. angle_tolerance .. ", Edge=" .. edge)

                    local load_status, model = pcall(function()
                        return importer:loadmodel(path, dev, angle_tolerance, edge)
                    end)

                    if load_status and model then
                        log("      [SUCCESS] Model loaded.")
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

                local load_status, model = pcall(function()
                    return importer:loadmodel(path, detail)
                end)

                if load_status and model then
                    log("      [SUCCESS] Model loaded.")
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
    log("Diagnostic Scan Complete.")
    pcall(function() system:inputdlg("Diagnostic Scan Complete. Check log: " .. log_file_full_path, "Done") end)
end

-- 2. Import Workflow Logic
function run_import_workflow(path, tolerance)
    log("Starting Import Workflow: " .. path .. " (Tol: " .. tolerance .. ")")
    last_error = ""

    local importer_indices = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    local success_overall = false

    for _, idx in ipairs(importer_indices) do
        -- Fix: Use system:createcadimport
        local ok_imp, importer = pcall(function() return system:createcadimport(idx) end)

        if ok_imp and importer then
            log("  Importer " .. idx .. " created.")

            local model = nil
            local load_success = false

            -- Attempt Syntax 1: loadmodel(path, deviation, angle_tol, max_edge_len)
            local angle_tol = 20
            local max_edge = 1000

            local ok1, m1 = pcall(function()
                return importer:loadmodel(path, tolerance, angle_tol, max_edge)
            end)

            if ok1 and m1 then
                model = m1
                load_success = true
                log("    Success: loadmodel(path, " .. tolerance .. ", " .. angle_tol .. ", " .. max_edge .. ") with Importer " .. idx)
            else
                log("    Failed Syntax 1 with Importer " .. idx .. ": " .. tostring(m1))
            end

            -- Try Syntax 2 (Detail Level) if Syntax 1 failed
            if not load_success then
                local detail = 3
                if tolerance < 0.05 then detail = 4 end
                if tolerance < 0.005 then detail = 5 end

                log("    Attempting Syntax 2 with Detail Level " .. detail)
                local ok2, m2 = pcall(function() return importer:loadmodel(path, detail) end)
                if ok2 and m2 then
                    model = m2
                    load_success = true
                    log("    Success: loadmodel(path, " .. detail .. ") with Importer " .. idx)
                end
            end

            if load_success and model then
                 -- Process Model and Add to Tray
                local count = 0
                local ok_count, c = pcall(function() return model:getmeshcount() end)
                if ok_count then count = c end

                log("    Entity Count: " .. count)

                if count > 0 then
                     if netfabbtrayhandler then
                         local t_ok, tray = pcall(function() return netfabbtrayhandler:gettray(0) end) -- Default to tray 0

                         if t_ok and tray then
                             local root = tray:getroot()
                             for i = 0, count - 1 do
                                -- Try getmesh first
                                local m_ok, mesh = pcall(function() return model:getmesh(i) end)
                                if not m_ok or not mesh then
                                    -- Try createsinglemesh
                                    m_ok, mesh = pcall(function() return model:createsinglemesh(i) end)
                                end

                                if m_ok and mesh then
                                    root:addmesh(mesh)
                                    log("      Added mesh " .. i .. " to tray.")
                                else
                                    log("      Failed to retrieve mesh " .. i)
                                end
                             end
                             pcall(function() application:triggerdesktopevent("updateparts") end)
                         else
                            log("    Could not access Tray 0.")
                         end
                     end
                     success_overall = true
                     break -- Stop searching on first success
                end
            end
        end
    end

    if not success_overall then
        last_error = "All importers (0-10) failed to load the model."
        log(last_error)
        return false
    end

    return true
end

-- --- GUI Callbacks ---

-- Functions must be GLOBAL to be called by name from the dialog engine
function on_btn_diagnostic()
    local path = system:showopenfiledialog('Select STEP file for Diagnostic', '*.stp;*.step')
    if not path or path == "" then return end
    run_diagnostic_scan(path)
end

function on_btn_import()
    local path = system:showopenfiledialog('Select STEP file for Import', '*.stp;*.step')
    if not path or path == "" then return end

    local tol = tonumber(edit_tolerance.text) or 0.1
    log("User Triggered Import. Path: " .. path .. " Tol: " .. tol)

    local success = run_import_workflow(path, tol)
    if success then
        pcall(function() system:inputdlg("Import Successful!", "Success") end)
    else
        pcall(function() system:inputdlg("Import Failed.\nReason: " .. last_error, "Error") end)
    end
end

function on_btn_close()
    if maindialog then maindialog:close() end
end

-- --- Main UI ---

local function show_main_dialog()
    maindialog = application:createdialog()
    maindialog.caption = "Unified STEP Importer Diagnostic"

    local group = maindialog:addgroupbox("Settings")
    group:addlabel("Import Tolerance (mm):")
    edit_tolerance = group:addedit("0.1")

    local btn_import = maindialog:addbutton("Import File (Best Guess)")
    -- FIX: onclick expects a STRING name of the global function, not the function itself
    btn_import.onclick = "on_btn_import"

    local btn_diag = maindialog:addbutton("Run Deep Diagnostic Scan")
    -- FIX: onclick expects a STRING name of the global function
    btn_diag.onclick = "on_btn_diagnostic"

    local btn_close = maindialog:addbutton("Close")
    -- FIX: onclick expects a STRING name of the global function
    btn_close.onclick = "on_btn_close"

    maindialog:show()
end

show_main_dialog()
