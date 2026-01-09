-- Diagnostic_Packing_Test.lua
-- Tests various packing methods to diagnose why parts are not moving.
-- Saves a log file to a user-specified directory.

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

log("--- Diagnostic Packing Test Started ---")
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
        -- matrix property returns a copy, but let's be safe
        local m = tm.matrix
        state[i] = m
    end
    return state
end

-- Helper: Restore Tray State
local function restore_tray_state(tray, state)
    if not tray or not tray.root then return end
    for i = 0, tray.root.meshcount - 1 do
        local tm = tray.root:getmesh(i)
        if state[i] then
            tm:setmatrix(state[i])
        end
    end
    -- Trigger update if possible
    if application and application.triggerdesktopevent then
        application:triggerdesktopevent('updateparts')
    end
end

-- Test Runner Function
local function run_test(tray, test_name, packer_id, setup_func, keep_changes)
    log("TEST: " .. test_name)

    -- Check for locked parts
    for i = 0, tray.root.meshcount - 1 do
        local tm = tray.root:getmesh(i)
        local is_locked_prop = false
        pcall(function() is_locked_prop = tm.lockedposition end)

        local restriction = "unknown"
        pcall(function() restriction = tm:getpackingoption('restriction') end)

        if is_locked_prop or restriction == 'locked' then
            log("  WARNING: Part " .. i .. " ("..tm.name..") is LOCKED. Prop="..tostring(is_locked_prop)..", Opt="..tostring(restriction))
        end
    end

    local initial_state = get_tray_state(tray)

    local p_ok, packer = pcall(function() return tray:createpacker(packer_id) end)
    if not p_ok or not packer then
        log("  FAILED to create packer (ID: " .. tostring(packer_id) .. ")")
        log("--------------------------------------------------")
        return
    end

    -- Apply settings
    if setup_func then
        local s_ok, s_err = pcall(function() setup_func(packer) end)
        if not s_ok then
            log("  Error applying settings: " .. tostring(s_err))
        end
    end

    log("  Running pack()...")
    local pack_ok, pack_res = pcall(function() return packer:pack() end)

    if pack_ok then
        log("  Pack returned code: " .. tostring(pack_res))
    else
        log("  Pack CRASHED: " .. tostring(pack_res))
    end

    -- Verification
    local moved_count = 0
    local mesh_count = tray.root.meshcount
    for i = 0, mesh_count - 1 do
        local tm = tray.root:getmesh(i)
        local old_m = initial_state[i]
        local new_m = tm.matrix
        if not matrix_equals(old_m, new_m) then
            moved_count = moved_count + 1
        end
    end

    log("  Result: " .. moved_count .. " of " .. mesh_count .. " parts moved.")

    -- Restore
    if keep_changes then
        log("  Keeping changes for visual inspection.")
        if application and application.triggerdesktopevent then
            application:triggerdesktopevent('updateparts')
        end
    else
        restore_tray_state(tray, initial_state)
        log("  State restored.")
    end
    log("--------------------------------------------------")
end

-- Main Loop
local function main()
    if not _G.netfabbtrayhandler then
        log("Error: netfabbtrayhandler not found.")
        return
    end

    log("Tray Count: " .. netfabbtrayhandler.traycount)

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

    -- Log Tray Info
    log("Tray Size: " .. target_tray.machinesize_x .. " x " .. target_tray.machinesize_y .. " x " .. target_tray.machinesize_z)

    -- TEST 1: TrueShape 2D (Centered / Sweetspot)
    -- Tries to pack around the center of the tray (useful for cylinders).
    -- run_test(target_tray, "TrueShape 2D (Centered)", target_tray.packingid_trueshape, function(p)
    --     p.packing_2d = true
    --     p.minimaldistance = 2.0

    --     -- Attempt to center packing (Fix for Cylinder/No-Build Zones)
    --     local cx = target_tray.machinesize_x / 2.0
    --     local cy = target_tray.machinesize_y / 2.0
    --     pcall(function()
    --         p.part_placement = p.place_sweetspot
    --         p.sweetspot_x = cx
    --         p.sweetspot_y = cy
    --         log("  Configured TrueShape Sweetspot: (" .. cx .. ", " .. cy .. ")")
    --     end)
    -- end, true)


    -- TEST 3b: Monte Carlo (Z-Only Rotation + Safe Margin)
    -- This addresses "Script 9 works but rotates X/Y" AND "packing on no-build zone".
    run_test(target_tray, "Monte Carlo (Z-Only + Margin)", target_tray.packingid_montecarlo, function(p)
        p.packing_quality = -1
        p.z_limit = 0.0
        p.start_from_current_positions = false

        -- 1. Restrict Rotation (Z-Only)
        local set_ok = pcall(function() p.defaultpartrotation = 1 end)
        if not set_ok then
            log("  Notice: 'defaultpartrotation' property not supported on this packer.")
        else
            log("  Configured Monte Carlo for Z-Axis Rotation Only.")
        end

        -- 2. Apply Safe Margin (Avoid No-Build Zones)
        -- Shrink packing volume by 10mm on all sides
        local margin = 10.0
        local ob_ok, ob = pcall(function() return p:getoutbox() end)
        if ob_ok and ob then
            ob.minx = ob.minx + margin
            ob.miny = ob.miny + margin
            ob.maxx = ob.maxx - margin
            ob.maxy = ob.maxy - margin
            -- Ensure we didn't invert the box (if tray is tiny)
            if ob.maxx > ob.minx and ob.maxy > ob.miny then
                p:setoutbox(ob)
                log("  Applied packing margin of " .. margin .. "mm to avoid no-build zones.")
            else
                log("  Warning: Tray too small to apply " .. margin .. "mm margin.")
            end
        else
            log("  Failed to retrieve/set packer outbox.")
        end
    end, true)

    -- TEST 3c: Monte Carlo (No Rotation)
    -- run_test(target_tray, "Monte Carlo (No Rotation)", target_tray.packingid_montecarlo, function(p)
    --     p.packing_quality = -1
    --     p.z_limit = 0.0
    --     p.start_from_current_positions = false
    --     pcall(function() p.defaultpartrotation = 2 end) -- 2: Forbidden
    -- end)

    -- TEST 4: Scanline 2D
    -- run_test(target_tray, "Scanline 2D", target_tray.packingid_2d, function(p)
    --     p.rastersize = 1
    --     p.anglecount = 4
    --     p.placeoutside = true
    --     p.packonlyselected = false
    --     p.borderspacingxy = 2
    -- end)

    -- TEST 5: Outbox Packer
    -- run_test(target_tray, "Outbox Packer", target_tray.packingid_outbox, function(p)
    --     p.minimaldistance = 2.0
    --     p.pack2D = false
    -- end)

    log("--- Diagnostic Complete ---")
    if system and system.messagedlg then
        system:messagedlg("Diagnostic Complete. Check log file.")
    end
end

pcall(main)
