-- Workflow_STEP_Importer.lua
-- GUI-based workflow for diagnosing STEP import issues and testing tolerances.
-- Updates: Removed io dependency, added robust logging, cascading loadmodel attempts.

-- --- Logging Setup ---
local log_path = "C:\\Users\\Public\\Documents\\netfabb_step_debug.txt"
if system and system.logtofile then
    -- Try to set log file immediately
    pcall(function() system:logtofile(log_path) end)
end

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Starting Workflow_STEP_Importer (v2) ---")
log("Log file set to: " .. log_path)

-- Global Variables
local maindialog = nil
local edit_tolerance = nil
local last_error = ""

-- --- Helper Functions ---

local function get_tray()
    if netfabbtrayhandler then
        local ok, t = pcall(function() return netfabbtrayhandler:gettray(0) end)
        if ok and t then return t end
    end
    if tray then return tray end
    return nil
end

-- Core Import Function with Cascading Attempts
local function run_import(path, tolerance, add_to_tray, name_suffix)
    log("Starting Import: " .. path .. " (Tol: " .. tolerance .. ")")
    last_error = ""

    local ok_imp, importer = pcall(function() return system:createcadimport(0) end)
    if not ok_imp or not importer then
        last_error = "Failed to create CAD importer."
        log("Error: " .. last_error)
        return nil
    end

    local model = nil
    local load_success = false
    local attempts = {}

    -- Attempt 1: 4 Arguments (path, tol, edge_angle, face_angle) - Common in recent versions
    -- 20, 20 are placeholder values found in Script6
    table.insert(attempts, "4-args")
    local ok1, m1 = pcall(function() return importer:loadmodel(path, tolerance, 20, 20) end)
    if ok1 and m1 then
        model = m1
        load_success = true
        log("Success: loadmodel(path, tol, 20, 20) worked.")
    else
        log("Attempt 1 (4-args) failed: " .. tostring(m1))
    end

    -- Attempt 2: 2 Arguments (path, tol) - BaseRoutines style
    if not load_success then
        table.insert(attempts, "2-args")
        local ok2, m2 = pcall(function() return importer:loadmodel(path, tolerance) end)
        if ok2 and m2 then
            model = m2
            load_success = true
            log("Success: loadmodel(path, tol) worked.")
        else
            log("Attempt 2 (2-args) failed: " .. tostring(m2))
        end
    end

    -- Attempt 3: 1 Argument (path) - Fallback ignoring tolerance
    if not load_success then
        table.insert(attempts, "1-arg")
        local ok3, m3 = pcall(function() return importer:loadmodel(path) end)
        if ok3 and m3 then
            model = m3
            load_success = true
            log("Success: loadmodel(path) worked (Tolerance ignored).")
        else
            log("Attempt 3 (1-arg) failed: " .. tostring(m3))
        end
    end

    if not load_success or not model then
        last_error = "All loadmodel attempts failed."
        log("Error: " .. last_error)
        return nil
    end

    local count = 0
    pcall(function() count = model.entitycount end)
    log("Entities found: " .. count)

    if count == 0 then
        last_error = "Model loaded but contains 0 entities."
        log("Warning: " .. last_error)
        return nil
    end

    if add_to_tray then
        local tray = get_tray()
        if tray then
            local root = tray.root
            for i = 0, count - 1 do
                local ok_m, mesh = pcall(function() return model:createsinglemesh(i) end)
                if ok_m and mesh then
                    local ok_add, item = pcall(function() return root:addmesh(mesh) end)
                    if ok_add and item and name_suffix then
                        pcall(function() item.name = "Part" .. name_suffix .. "_" .. i end)
                    end
                end
            end
            pcall(function() application:triggerdesktopevent("updateparts") end)
        else
            log("Warning: No active tray to add parts to.")
        end
    end
    return true
end

-- Alternative Import using system:importfile
local function run_importfile(path)
    log("Starting Alternative Import (system:importfile): " .. path)
    local ok, parts = pcall(function() return system:importfile(path) end)

    if ok and parts then
        log("system:importfile success. Type: " .. type(parts))
        if type(parts) == 'table' then
             log("Imported " .. #parts .. " parts.")
             return true
        end
        return true -- It worked, but maybe return structure varies
    else
        last_error = "system:importfile failed: " .. tostring(parts)
        log("Error: " .. last_error)
        return false
    end
end

-- --- Dialog Callbacks ---

-- 1. Standard Import
function on_import_standard()
    local path = system:showopendialog("*.stp;*.step")
    if not path or path == "" then return end

    local tol = tonumber(edit_tolerance.text) or 0.1
    log("User Triggered: Standard Import. Tol: " .. tol)

    local success = run_import(path, tol, true, "_Tol" .. tol)
    if success then
        system:messagedlg("Import Successful!")
    else
        system:messagedlg("Import Failed.\nReason: " .. last_error .. "\n\nLog saved to:\n" .. log_path)
    end
end

-- 2. Alternative Import
function on_import_alt()
    local path = system:showopendialog("*.stp;*.step")
    if not path or path == "" then return end

    log("User Triggered: Alternative Import.")

    local success = run_importfile(path)
    if success then
        system:messagedlg("Alternative Import Successful!")
    else
        system:messagedlg("Alternative Import Failed.\nReason: " .. last_error .. "\n\nLog saved to:\n" .. log_path)
    end
end

-- 3. Sweep
function on_import_sweep()
    local path = system:showopendialog("*.stp;*.step")
    if not path or path == "" then return end

    log("User Triggered: Sweep Import.")
    local tols = {0.001, 0.01, 0.1, 1.0, 5.0}
    local success_count = 0

    for _, tol in ipairs(tols) do
        if run_import(path, tol, true, "_Sweep_Tol" .. tol) then
            success_count = success_count + 1
        end
    end

    if success_count > 0 then
        system:messagedlg("Sweep Complete. Imported " .. success_count .. "/" .. #tols .. " variations.\nCheck Tray.")
    else
        system:messagedlg("Sweep Failed. No variations imported.\nReason: " .. last_error .. "\n\nLog saved to:\n" .. log_path)
    end
end

-- Close
function maindialog_close()
    maindialog:close(true)
end

-- --- Main UI Creation ---

function show_workflow_dialog()
    local width = 500
    local dlg = application:createdialog()
    dlg.caption = "Diagnostic STEP Importer Workflow"
    dlg.width = width
    maindialog = dlg

    -- Group: Settings
    local g_set = dlg:addgroupbox()
    g_set.caption = "Import Settings"
    g_set.borderstyle = 1
    g_set.verticalpadding = 10

    local split_set = g_set:addsplitter()
    split_set:settoleft()
    local lbl_tol = split_set:addlabel()
    lbl_tol.caption = "Tolerance (mm):"

    split_set:settoright()
    edit_tolerance = split_set:addedit()
    edit_tolerance.text = "0.1"

    -- Info Label
    local lbl_info = g_set:addlabel()
    lbl_info.caption = "Tolerance: Max deviation from CAD surface.\nSmaller = Higher resolution (more triangles).\nLarger = Coarser mesh (fewer triangles)."

    -- Group: Actions
    local g_act = dlg:addgroupbox()
    g_act.caption = "Actions"
    g_act.borderstyle = 1
    g_act.verticalpadding = 10

    -- Button 1: Standard
    local b_std = g_act:addbutton()
    b_std.caption = "Import File (Standard)"
    b_std.onclick = "on_import_standard"

    -- Button 2: Alt
    local b_safe = g_act:addbutton()
    b_safe.caption = "Alternative Import (importfile)"
    b_safe.onclick = "on_import_alt"

    -- Button 3: Sweep
    local b_sweep = g_act:addbutton()
    b_sweep.caption = "Run Tolerance Sweep (0.001 - 5.0)"
    b_sweep.onclick = "on_import_sweep"

    -- Close Button
    local split_bot = dlg:addsplitter()
    split_bot:settoright()
    local b_close = split_bot:addbutton()
    b_close.caption = "Close"
    b_close.onclick = "maindialog_close"

    dlg:show()
end

-- Run
show_workflow_dialog()
