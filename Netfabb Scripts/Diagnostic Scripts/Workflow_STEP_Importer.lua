-- Workflow_STEP_Importer.lua
-- GUI-based workflow for diagnosing STEP import issues and testing tolerances.
-- Updates: Extended importer search (0-10), fixed loadmodel syntax, robust pcall.

-- --- Logging Setup ---
local log_file_path = "C:\\Users\\Public\\Documents\\netfabb_step_workflow_log.txt"
pcall(function() system:logtofile(log_file_path) end)

local function log(msg)
    pcall(function() system:log(msg) end)
end

log("--- Starting Workflow_STEP_Importer (v5) ---")
log("Log file target: " .. log_file_path)

-- Global Variables
local maindialog = nil
local edit_tolerance = nil
local last_error = ""

-- --- Helper Functions ---

-- Core Import Function
local function run_import(path, tolerance, add_to_tray, name_suffix)
    log("Starting Import: " .. path .. " (Tol: " .. tolerance .. ")")
    last_error = ""

    local importer_indices = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
    local success_overall = false

    for _, idx in ipairs(importer_indices) do
        -- Wrapped pcall for creation
        local ok_imp, importer = pcall(function() return system:createcadimporter(idx) end)

        if ok_imp and importer then
            log("  Importer " .. idx .. " created.")

            -- Attempt Syntax 1: loadmodel(path, deviation, angle_tol, max_edge_len)
            -- Using 20 deg angle and 1000 edge length to respect tolerance primarily.

            local model = nil
            local load_success = false

            -- Try Syntax 1
            local ok1, m1 = pcall(function()
                return importer:loadmodel(path, tolerance, 20, 1000)
            end)

            if ok1 and m1 then
                model = m1
                load_success = true
                log("    Success: loadmodel(path, " .. tolerance .. ", 20, 1000) with Importer " .. idx)
            else
                log("    Failed Syntax 1 with Importer " .. idx .. ": " .. tostring(m1))
            end

            -- Try Syntax 2 (Detail Level) if Syntax 1 failed
            if not load_success then
                local detail = 3
                if tolerance < 0.05 then detail = 4 end
                if tolerance < 0.005 then detail = 5 end

                local ok2, m2 = pcall(function() return importer:loadmodel(path, detail) end)
                if ok2 and m2 then
                    model = m2
                    load_success = true
                    log("    Success: loadmodel(path, " .. detail .. ") with Importer " .. idx)
                end
            end

            if load_success and model then
                 -- Process Model
                local count = 0
                local ok_count, c = pcall(function() return model:getmeshcount() end)
                if ok_count then count = c end

                log("    Entity Count: " .. count)

                if count > 0 then
                     if add_to_tray and netfabbtrayhandler then
                         local t_ok, tray = pcall(function() return netfabbtrayhandler:gettray(0) end)
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
                                else
                                    log("    Failed to retrieve mesh " .. i)
                                end
                             end
                             pcall(function() application:triggerdesktopevent("updateparts") end)
                         end
                     end
                     success_overall = true
                     break -- Stop searching on first success
                end
            end
        end
    end

    if not success_overall then
        last_error = "All importers (0-10) failed."
        log(last_error)
        return false
    end

    return true
end

-- --- Dialog Callbacks ---

-- 1. Standard Import
function on_import_standard()
    local path = system:showopenfiledialog("Select STEP", "*.stp;*.step")
    if not path or path == "" then return end

    local tol = tonumber(edit_tolerance.text) or 0.1
    log("User Triggered: Import. Tol: " .. tol)

    local success = run_import(path, tol, true, "_Tol" .. tol)
    if success then
        pcall(function() system:inputdlg("Import Successful!", "Success") end)
    else
        pcall(function() system:inputdlg("Import Failed.\nReason: " .. last_error, "Error") end)
    end
end

-- Close
function maindialog_close()
    maindialog:close()
end

-- --- Main UI Creation ---

function show_workflow_dialog()
    maindialog = application:createdialog()
    maindialog.caption = "Diagnostic STEP Importer Workflow v5"

    local group = maindialog:addgroupbox("Settings")
    local lbl = group:addlabel("Tolerance (mm):")
    edit_tolerance = group:addedit("0.1")

    local btn_import = maindialog:addbutton("Import File")
    btn_import.onclick = on_import_standard

    local btn_close = maindialog:addbutton("Close")
    btn_close.onclick = maindialog_close

    maindialog:show()
end

show_workflow_dialog()
