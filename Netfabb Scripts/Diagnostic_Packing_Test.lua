-- Diagnostic_Packing_Test.lua
-- Focused diagnostic script for TrueShape 2D Packer.
-- Forces a repack by moving parts outside the build volume first.

-- Standard Logging Setup
local function log(msg)
    if system and system.log then
        system:log(msg)
    end
    print(msg)
end

-- 1. Prompt for Directory Path
local path_variable = ""
local ok_input, input_path = pcall(function() return system:inputdlg("Enter Path to Save Log File:", "Diagnostic Log Path", "C:\\") end)

if ok_input and input_path and input_path ~= "" then
    path_variable = input_path
else
    log("No directory selected. Exiting.")
    return
end

path_variable = string.gsub(path_variable, '"', '')
if path_variable == "" then return end
if string.sub(path_variable, -1) ~= "\\" then path_variable = path_variable .. "\\" end

local log_file_path = path_variable .. "diagnostic_packing_log.txt"
if system and system.logtofile then
    pcall(function() system:logtofile(log_file_path) end)
end

log("--- Diagnostic Packing Test Started (TrueShape 2D Only) ---")
log("Log file: " .. log_file_path)

-- Helper: Check Matrix Equality
local function matrix_equals(m1, m2)
    if not m1 or not m2 then return false end
    for r = 0, 3 do
        for c = 0, 3 do
            if math.abs(m1:get(r,c) - m2:get(r,c)) > 0.001 then
                return false
            end
        end
    end
    return true
end

-- Helper: Get Tray State (Matrices)
local function get_tray_state(tray)
    local state = {}
    if not tray or not tray.root then return state end
    for i = 0, tray.root.meshcount - 1 do
        local tm = tray.root:getmesh(i)
        local m = tm.matrix
        state[i] = m
    end
    return state
end

-- Helper: Move Parts Outside
-- Shifts all non-locked parts to a position likely outside the build plate
local function move_parts_outside(tray)
    log("  Moving parts outside build plate to force repacking...")
    local moved = 0
    for i = 0, tray.root.meshcount - 1 do
        local tm = tray.root:getmesh(i)

        -- Check locked
        local is_locked = false
        pcall(function() is_locked = tm.lockedposition end)
        local restriction = "unknown"
        pcall(function() restriction = tm:getpackingoption('restriction') end)

        if not is_locked and restriction ~= 'locked' then
            -- Translate to negative X/Y (outside platform)
            -- We move relative to current outbox to ensure clearing
            local ob = nil
            pcall(function() ob = tm.outbox end)
            if ob then
                -- Move to Left-Bottom of current position
                tm:translate(-200 - ob.maxx, -200 - ob.maxy, 0)
                moved = moved + 1
            else
                -- Fallback
                tm:translate(-500, -500, 0)
                moved = moved + 1
            end
        end
    end
    log("  Moved " .. moved .. " parts.")
end

-- Main Test Function
local function main()
    if not _G.netfabbtrayhandler then
        log("Error: netfabbtrayhandler not found.")
        return
    end

    local target_tray = nil
    for i = 0, netfabbtrayhandler.traycount - 1 do
        local t = netfabbtrayhandler:gettray(i)
        if t and t.root and t.root.meshcount > 0 then
            target_tray = t
            log("Selected Tray " .. (i+1) .. " for testing. (Part Count: " .. t.root.meshcount .. ")")
            break
        end
    end

    if not target_tray then
        log("No suitable tray with parts found. Please load parts before running.")
        return
    end

    log("Tray Size: " .. target_tray.machinesize_x .. " x " .. target_tray.machinesize_y .. " x " .. target_tray.machinesize_z)

    -- 1. Move Parts Outside
    move_parts_outside(target_tray)

    -- 2. Capture State (Post-Move)
    local pre_pack_state = get_tray_state(target_tray)

    -- 3. Run Monte Carlo Packer (Z-Limit 1mm)
    log("TEST: Monte Carlo (Z-Limit 1mm)")
    local p_ok, packer = pcall(function() return target_tray:createpacker(target_tray.packingid_montecarlo) end)

    if not p_ok or not packer then
        log("  FAILED to create Monte Carlo packer.")
        return
    end

    -- Configure Packer
    local cfg_ok, cfg_err = pcall(function()
        packer.z_limit = 1.0
        packer.minimaldistance = 1.0
        packer.packing_quality = -1 -- Default/High
        packer.start_from_current_positions = false

        -- Restrict Rotation: Z-Axis Only
        pcall(function() packer.defaultpartrotation = 1 end)
    end)

    if not cfg_ok then
        log("  Error configuring packer: " .. tostring(cfg_err))
    end

    log("  Running pack()...")
    local pack_ok, pack_res = pcall(function() return packer:pack() end)

    if pack_ok then
        log("  Pack returned code: " .. tostring(pack_res))
    else
        log("  Pack CRASHED: " .. tostring(pack_res))
    end

    -- 4. Verification
    local moved_count = 0
    local mesh_count = target_tray.root.meshcount
    for i = 0, mesh_count - 1 do
        local tm = target_tray.root:getmesh(i)
        local old_m = pre_pack_state[i]
        local new_m = tm.matrix
        if not matrix_equals(old_m, new_m) then
            moved_count = moved_count + 1
        end
    end

    log("  Result: " .. moved_count .. " of " .. mesh_count .. " parts moved (from outside position).")
    log("  Keeping changes for visual inspection.")

    if application and application.triggerdesktopevent then
        application:triggerdesktopevent('updateparts')
    end

    log("--- Diagnostic Complete ---")
    if system and system.messagedlg then
        system:messagedlg("Diagnostic Complete. Check log file.")
    end
end

pcall(main)
