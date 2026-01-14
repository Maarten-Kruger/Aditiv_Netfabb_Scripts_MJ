-- Diagnostic_Report_Test.lua
-- Tests generating a report from a custom ODT template to extract Build Time.
-- This script asks for an ODT template and an output directory, then generates the report.

-- Standard Logging Function
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
end

log("--- Script Started: Diagnostic Report Test ---")

local success_main, err_main = pcall(function()

    -- 1. Prompt for Template File (ODT)
    local template_path = ""
    local ok_temp, input_temp = pcall(function() return system:showopendialog("*.odt") end)

    if ok_temp and input_temp and input_temp ~= "" then
        template_path = input_temp
        -- Sanitize path
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

    -- Try with 3 arguments
    ok_dir, input_dir = pcall(function() return system:showdirectoryselectdialog(title, default_path, true) end)

    -- Retry with 2 arguments
    if not ok_dir then
        ok_dir, input_dir = pcall(function() return system:showdirectoryselectdialog(title, default_path) end)
    end

    -- Fallback to system:inputdlg
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

    -- 3. Construct Output File Path
    local output_file = output_dir .. "Report_Output.odt"
    log("Target Output File: " .. output_file)

    -- 4. Get Tray
    local tray = _G.tray
    if not tray then
        if _G.netfabbtrayhandler and _G.netfabbtrayhandler.traycount > 0 then
            tray = _G.netfabbtrayhandler:gettray(0)
            log("Using first tray from handler.")
        end
    else
        log("Using active tray (_G.tray).")
    end

    if not tray then
        error("No available tray found.")
    end

    -- 5. Generate Report
    log("Initializing Snapshot Creator...")
    local snapshot = system:createsnapshotcreator()

    log("Initializing Report Generator...")
    local reportgenerator = system:createreportgenerator(snapshot)

    log("Generating Report for Tray...")
    -- The API is createreportfortray(tray, template_path, output_path)
    reportgenerator:createreportfortray(tray, template_path, output_file)

    log("Report generation command issued.")

    -- Verify if file exists (if we can)
    -- Since we don't have lfs, we assume success if no error was thrown.

    pcall(function() system:inputdlg("Report Generation Complete.\nFile: " .. output_file, "Success", "Success") end)

end)

if not success_main then
    log("Critical Error: " .. tostring(err_main))
    pcall(function() system:inputdlg("Script Error: " .. tostring(err_main), "Error", "Error") end)
end

-- Detach log
if system and system.logtofile then
    pcall(function() system:logtofile("") end)
end
