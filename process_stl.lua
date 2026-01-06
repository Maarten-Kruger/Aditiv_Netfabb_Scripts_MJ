--[[
  Process STL Script
  Imports, Rotates, Scales, and Exports an STL file.

  Input: C:\Users\Maarten\OneDrive\Desktop\density sample.stl
  Output: C:\Users\Maarten\OneDrive\Desktop\density sample MODIFIED.stl

  Transformations:
  - Rotate: X=60, Y=40
  - Scale: 50%
--]]

local input_path = [[C:\Users\Maarten\OneDrive\Desktop\density sample.stl]]
local output_path = [[C:\Users\Maarten\OneDrive\Desktop\density sample MODIFIED.stl]]
local log_path = [[C:\Users\Public\Documents\netfabb_process_log.txt]]

-- Setup Logging
if system and system.logtofile then
    pcall(function() system:logtofile(log_path) end)
end

local function log(msg)
    if system and system.log then
        system:log(msg)
    end
    print(msg) -- Fallback
end

log("--- Process STL Script Started ---")

local function safe_call(func, ...)
    local args = {...}
    local ok, res = pcall(function() return func(unpack(args)) end)
    if ok then
        return true, res
    else
        log("Error: " .. tostring(res))
        return false, res
    end
end

-- 1. Import STL
log("Importing: " .. input_path)
if not system or not system.load then
    log("ERROR: system.load not available.")
    return
end

local ok_load, loaded_obj = safe_call(system.load, input_path)

if not ok_load then
    log("Failed to load file.")
    return
end

-- 2. Find the Loaded Part
-- system:load might return the part, or we check the tray.
local part = nil

if loaded_obj and type(loaded_obj) ~= "boolean" then
    part = loaded_obj
    log("system:load returned an object.")
else
    -- Check tray for the last part
    if tray and tray.root then
        local count = 0
        local ok_c, c = pcall(function() return tray.root.itemcount end)
        if ok_c then count = c end

        if count > 0 then
            part = tray.root:getitem(count - 1)
            log("Retrieved last item from tray (index " .. (count - 1) .. ")")
        else
            -- Try meshcount fallback
            local mc = 0
            local ok_mc, m = pcall(function() return tray.root.meshcount end)
            if ok_mc then mc = m end
            if mc > 0 then
                part = tray.root:getmesh(mc - 1)
                log("Retrieved last mesh from tray (index " .. (mc - 1) .. ")")
            end
        end
    elseif system.getPartCount then
        local pc = system.getPartCount()
        if pc > 0 then
            part = system.getPart(pc - 1)
            log("Retrieved last part from system (index " .. (pc - 1) .. ")")
        end
    end
end

if not part then
    log("ERROR: Could not find the loaded part.")
    return
end

log("Part found. Applying transformations...")

-- 3. Rotate (X=60, Y=40, Z=0)
-- Note: Rotation order matters. We assume standard behavior.
local rot_ok = false
if part.rotate then
    log("Rotating using part:rotate(60, 40, 0)")
    local ok, err = pcall(function() part:rotate(60, 40, 0) end)
    if ok then rot_ok = true else log("part:rotate failed: " .. tostring(err)) end
else
    log("part:rotate method not found. Trying matrix manipulation...")
    -- Fallback: Modify matrix directly if possible (complex without explicit Matrix API)
    -- We'll assume rotate exists as it's standard.
end

if not rot_ok then
    log("WARNING: Rotation failed or method not found.")
end

-- 4. Scale (50%)
local scale_ok = false
if part.scale then
    log("Scaling using part:scale(0.5)")
    -- Try uniform scaling first
    local ok, err = pcall(function() part:scale(0.5) end)
    if not ok then
        log("part:scale(0.5) failed, trying part:scale(0.5, 0.5, 0.5)")
        ok, err = pcall(function() part:scale(0.5, 0.5, 0.5) end)
    end
    if ok then scale_ok = true else log("part:scale failed: " .. tostring(err)) end
end

if not scale_ok then
    log("WARNING: Scaling failed or method not found.")
end

-- 5. Export
log("Exporting to: " .. output_path)
local exported = false

-- Try part:exportSTL
if part.exportSTL then
    log("Trying part:exportSTL...")
    local ok, err = pcall(function() part:exportSTL(output_path) end)
    if ok then exported = true end
end

-- Try part:save
if not exported and part.save then
    log("Trying part:save...")
    local ok, err = pcall(function() part:save(output_path) end)
    if ok then exported = true end
end

-- Try mesh export if part wraps a mesh
if not exported and part.getmesh then
    log("Trying to get mesh and save...")
    local ok, mesh = pcall(function() return part:getmesh(0) end)
    if ok and mesh and mesh.save then
        local ok_save, err = pcall(function() mesh:save(output_path) end)
        if ok_save then exported = true end
    end
end

-- Try system:saveSTL (if exists)
if not exported and system.saveSTL then
    log("Trying system:saveSTL...")
    local ok, err = pcall(function() system:saveSTL(part, output_path) end)
    if ok then exported = true end
end

if exported then
    log("Export successful.")
else
    log("ERROR: Failed to export part.")
end

log("--- Process STL Script Finished ---")
