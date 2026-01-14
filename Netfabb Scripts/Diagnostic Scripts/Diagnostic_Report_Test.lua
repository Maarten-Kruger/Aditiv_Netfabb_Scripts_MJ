-- Diagnostic_Report_Test.lua
-- Tests generating a report from a custom ODT template to extract Build Time.
-- Tries multiple methods (Active Tray, Handler Tray, Mesh, Project) to ensure data population.

-- Standard Logging Function
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Script Started: Diagnostic Report Test (Multi-Method) ---")

local success_main, err_main = pcall(function()

    -- 1. Prompt for Template File (ODT)
    local template_path = ""
    local ok_temp, input_temp = pcall(function() return system:showopendialog("*.odt") end)

    if ok_temp and input_temp and input_temp ~= "" then
        template_path = input_temp
        template_path = string.gsub(template_path, '"', '')
        log("User provided template path: " .. template_path)
    else
        log("No template selected or dialog cancelled.")
        pcall(function() system:inputdlg("No template selected. Script will exit.", "Error", "Error") end)
        return
    end

    -- 2. Prompt for Output Directory
    local output_dir = ""
    local ok_dir, input_dir = false, nil
    local default_path = "C:\\"
    local title = "Select Output Folder"

    ok_dir, input_dir = pcall(function() return system:showdirectoryselectdialog(title, default_path, true) end)
    if not ok_dir then
        ok_dir, input_dir = pcall(function() return system:showdirectoryselectdialog(title, default_path) end)
    end
    if not ok_dir then
        ok_dir, input_dir = pcall(function() return system:inputdlg(title, title, default_path) end)
    end

    if ok_dir and input_dir and input_dir ~= "" then
        output_dir = input_dir
        output_dir = string.gsub(output_dir, '"', '')
        if string.sub(output_dir, -1) ~= "\\" then
            output_dir = output_dir .. "\\"
        end
        log("User provided output directory: " .. output_dir)
    else
        log("No directory selected.")
        pcall(function() system:inputdlg("No directory selected. Script will exit.", "Error", "Error") end)
        return
    end

    -- Setup Logging to File
    local log_file_path = output_dir .. "diagnostic_report_log.txt"
    if system and system.logtofile then
        pcall(function() system:logtofile(log_file_path) end)
    end
    log("--- Script Logging Initialized ---")
    log("Template: " .. template_path)
    log("Output Dir: " .. output_dir)

    -- TRIGGER UPDATE
    log("Triggering desktop event 'updateparts'...")
    pcall(function() application:triggerdesktopevent('updateparts') end)

    -- Report Generation Helper
    local function generate(label, func_name, entity, t_path, out_file)
        log("Attempting Method: " .. label)

        local ok, err = pcall(function()
            local snapshot = system:createsnapshotcreator()
            local reportgenerator = system:createreportgenerator(snapshot)

            -- Call the specific function (createreportfortray or createreportformesh)
            if func_name == "createreportfortray" then
                reportgenerator:createreportfortray(entity, t_path, out_file)
            elseif func_name == "createreportformesh" then
                reportgenerator:createreportformesh(entity, t_path, out_file)
            else
                error("Unknown function name: " .. func_name)
            end
        end)

        if ok then
            log("  SUCCESS: " .. label .. " -> " .. out_file)
            return true
        else
            log("  FAILED: " .. label .. " -> Error: " .. tostring(err))
            return false
        end
    end

    -- METHOD 1: _G.tray (Active Tray)
    if _G.tray then
        local out_1 = output_dir .. "Report_1_ActiveTray.odt"
        generate("Active Tray (_G.tray)", "createreportfortray", _G.tray, template_path, out_1)

        -- PROBE: Check for attributes (Diagnostic only)
        local attr_ok, attr_val = pcall(function() return _G.tray:getattribute("BuildTimeEstimation") end)
        log("  Probe _G.tray:getattribute('BuildTimeEstimation'): " .. tostring(attr_ok) .. " / " .. tostring(attr_val))
    else
        log("Method 1 Skipped: _G.tray is nil")
    end

    -- METHOD 2: netfabbtrayhandler Trays
    if _G.netfabbtrayhandler then
        local count = 0
        pcall(function() count = _G.netfabbtrayhandler.traycount end)
        log("Netfabb Tray Handler Count: " .. count)

        for i = 0, count - 1 do
            local tray = _G.netfabbtrayhandler:gettray(i)
            if tray then
                local out_2 = output_dir .. "Report_2_HandlerTray_" .. i .. ".odt"
                generate("Handler Tray " .. i, "createreportfortray", tray, template_path, out_2)
            end
        end
    end

    -- METHOD 3: First Mesh (createreportformesh)
    -- This tests if the generator works at all for this template on a mesh level
    if _G.tray and _G.tray.root and _G.tray.root.meshcount > 0 then
        local mesh = _G.tray.root:getmesh(0)
        local out_3 = output_dir .. "Report_3_FirstMesh.odt"
        generate("First Mesh (Active Tray)", "createreportformesh", mesh, template_path, out_3)
    end

    -- METHOD 4: Fabbproject Trays (if available)
    if _G.fabbproject then
        log("Fabbproject found. Attempting Project Trays...")
        local fp_count = 0
        pcall(function() fp_count = _G.fabbproject.traycount end)
        for i = 0, fp_count - 1 do
             local fp_tray = _G.fabbproject:gettray(i)
             if fp_tray then
                 local out_4 = output_dir .. "Report_4_ProjectTray_" .. i .. ".odt"
                 generate("Project Tray " .. i, "createreportfortray", fp_tray, template_path, out_4)
             end
        end
    else
        log("Fabbproject is nil. Skipping Method 4.")
    end

    pcall(function() system:inputdlg("Report Generation Attempts Complete.\nCheck output directory.", "Finished", "Success") end)

end)

if not success_main then
    log("Critical Error: " .. tostring(err_main))
    pcall(function() system:inputdlg("Script Error: " .. tostring(err_main), "Error", "Error") end)
end

if system and system.logtofile then
    pcall(function() system:logtofile("") end)
end
