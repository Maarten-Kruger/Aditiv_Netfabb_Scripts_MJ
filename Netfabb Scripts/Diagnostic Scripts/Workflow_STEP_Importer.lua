-- Workflow_STEP_Importer.lua
-- GUI-based workflow for diagnosing STEP import issues and testing tolerances.

-- Standard Logging
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

-- Global Dialog Variables
local maindialog = nil
local edit_tolerance = nil
local last_path = ""

-- --- Helper Functions ---

local function get_tray()
    if netfabbtrayhandler then
        local ok, t = pcall(function() return netfabbtrayhandler:gettray(0) end)
        if ok and t then return t end
    end
    if tray then return tray end
    return nil
end

local function file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then io.close(f) return true else return false end
end

local function copy_file(src, dst)
    -- Simple binary copy since os.execute might be restricted or slow
    local infile, err1 = io.open(src, "rb")
    if not infile then return false, "Read Error: " .. tostring(err1) end
    local content = infile:read("*a")
    infile:close()

    local outfile, err2 = io.open(dst, "wb")
    if not outfile then return false, "Write Error: " .. tostring(err2) end
    outfile:write(content)
    outfile:close()
    return true, nil
end

-- Core Import Function
local function run_import(path, tolerance, add_to_tray, name_suffix)
    log("Starting Import: " .. path .. " (Tol: " .. tolerance .. ")")

    local ok_imp, importer = pcall(function() return system:createcadimport(0) end)
    if not ok_imp or not importer then
        log("Error: Failed to create CAD importer.")
        return nil
    end

    local ok_load, model = pcall(function() return importer:loadmodel(path, tolerance) end)
    if not ok_load then
        log("Error: loadmodel crashed (Runtime Error). Path might be invalid or format unsupported.")
        return nil
    end
    if not model then
        log("Error: loadmodel returned nil.")
        return nil
    end

    local count = 0
    pcall(function() count = model.entitycount end)
    log("Success. Entities found: " .. count)

    if add_to_tray and count > 0 then
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

-- --- Dialog Callbacks ---

-- 1. Standard Import
function on_import_standard()
    local path = system:showopendialog("*.stp;*.step")
    if not path or path == "" then return end
    last_path = path

    local tol = tonumber(edit_tolerance.text) or 0.1
    log("User Triggered: Standard Import. Tol: " .. tol)

    local success = run_import(path, tol, true, "_Tol" .. tol)
    if success then
        system:messagedlg("Import Successful!")
    else
        system:messagedlg("Import Failed. Check Log.")
    end
end

-- 2. Safe Import (Copy)
function on_import_safe()
    local path = system:showopendialog("*.stp;*.step")
    if not path or path == "" then return end
    last_path = path

    local tol = tonumber(edit_tolerance.text) or 0.1
    log("User Triggered: Safe Import. Tol: " .. tol)

    -- Copy to Public Documents to avoid path issues
    local temp_path = "C:\\Users\\Public\\Documents\\temp_import_safe.stp"
    log("Copying to: " .. temp_path)

    local ok_cp, err_cp = copy_file(path, temp_path)
    if not ok_cp then
        log("Copy Failed: " .. tostring(err_cp))
        system:messagedlg("Could not create temp file. See log.")
        return
    end

    local success = run_import(temp_path, tol, true, "_Safe_Tol" .. tol)
    if success then
        system:messagedlg("Safe Import Successful!")
    else
        system:messagedlg("Safe Import Failed. Check Log.")
    end
end

-- 3. Sweep
function on_import_sweep()
    local path = system:showopendialog("*.stp;*.step")
    if not path or path == "" then return end
    last_path = path

    log("User Triggered: Sweep Import.")
    local tols = {0.001, 0.01, 0.1, 1.0, 5.0}

    for _, tol in ipairs(tols) do
        run_import(path, tol, true, "_Sweep_Tol" .. tol)
    end

    system:messagedlg("Sweep Complete. Check Tray.")
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

    -- Button 2: Safe
    local b_safe = g_act:addbutton()
    b_safe.caption = "Safe Import (Copy First)"
    b_safe.onclick = "on_import_safe"

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
