-- Pack_Trays_Scanline.lua
-- Deployment script to pack all trays using the Scanline 2D packer.
-- Recommended for reliable 2D packing.

-- Standard Logging Setup
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
    print(msg)
end

-- 1. Prompt for Directory Path (for logs)
local path_variable = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Path to Save Log File:", "Pack Log Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    log("No directory selected. Exiting.")
    return
end

path_variable = string.gsub(path_variable, '"', '')
if path_variable == "" then return end
if string.sub(path_variable, -1) ~= "\\" then path_variable = path_variable .. "\\" end

local log_file_path = path_variable .. "pack_scanline_log.txt"
if system and system.logtofile then
    pcall(function() system:logtofile(log_file_path) end)
end

log("--- Scanline 2D Packing Started ---")
log("Log file: " .. log_file_path)

-- Main Packing Function
local function main()
    if not _G.netfabbtrayhandler then
        log("Error: netfabbtrayhandler not available.")
        return
    end

    local tray_count = netfabbtrayhandler.traycount
    log("Processing " .. tray_count .. " trays...")

    for i = 0, tray_count - 1 do
        local tray = netfabbtrayhandler:gettray(i)
        local tray_name = "Tray " .. (i + 1)
        
        if tray then
            log("Packing " .. tray_name .. "...")
            
            -- Create Scanline 2D Packer
            local p_ok, packer = pcall(function() return tray:createpacker(tray.packingid_2d) end)
            
            if p_ok and packer then
                -- Configure Packer Settings
                local cfg_ok, cfg_err = pcall(function()
                    packer.rastersize = 1       -- Voxel size (mm)
                    packer.anglecount = 7       -- Rotation steps
                    packer.coarsening = 1       -- Accuracy
                    packer.placeoutside = true  -- Allow placing remaining parts outside
                    packer.borderspacingxy = 1.0 -- Spacing between parts/border
                    packer.packonlyselected = false -- Pack all parts
                end)
                
                if cfg_ok then
                    -- Execute Pack
                    local pack_ok, pack_res = pcall(function() return packer:pack() end)
                    if pack_ok then
                        log("  " .. tray_name .. ": Packing complete (Code: " .. tostring(pack_res) .. ").")
                    else
                        log("  " .. tray_name .. ": Packing CRASHED (" .. tostring(pack_res) .. ").")
                    end
                else
                    log("  " .. tray_name .. ": Failed to configure packer (" .. tostring(cfg_err) .. ").")
                end
            else
                log("  " .. tray_name .. ": Failed to create Scanline packer.")
            end
        else
            log("Error: Could not retrieve " .. tray_name)
        end
    end

    -- Update Desktop View
    if application and application.triggerdesktopevent then
        application:triggerdesktopevent('updateparts')
    end

    log("--- Scanline 2D Packing Complete ---")
    if system and system.messagedlg then
        system:messagedlg("Packing Complete.")
    end
end

-- Run Script
pcall(main)
