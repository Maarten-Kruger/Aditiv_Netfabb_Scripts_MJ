--[[
  Part_Rename_MJ.lua
  Renames parts in the active tray based on a weighted linear function starting from the origin.

  Logic:
  1. Find the part closest to the origin (0,0) [or best fitting the function from 0,0].
  2. Rename it to "000".
  3. Use this part as the reference for the next step.
  4. Find the next unlabelled part that minimizes the weighted function.
  5. Rename to "001", update reference, repeat.

  Function:
  Value = (Weight_Y * Y_Distance) + (Weight_Dist * Part_Distance) + (Weight_Spatter * Spatter_Boolean)

  Weights Configuration:
  The user requested "weights will be negative... smaller is better".
  - If "Smaller is Better", we minimize the Value.
  - To minimize Distance, we typically use a POSITIVE weight (Cost = 1 * Dist).
  - If using NEGATIVE weights (Cost = -1 * Dist), "Smaller" (-1000) means LARGER distance.
  - Below variables are set to Positive to MINIMIZE distance (Standard Proximity Sort).
  - CHANGE TO NEGATIVE if you wish to MAXIMIZE distance (Jump to farthest).
--]]

-- === CONFIGURATION ===
local Weight_Y_Distance = 100.0       -- Weight for vertical Y distance
local Weight_Part_Distance = 20.0    -- Weight for Euclidean distance
local Weight_Spatter_Area = 5000.0  -- Weight for Spatter Area (Penalty if Positive)
local Spatter_Angle = 30.0          -- Angle in degrees for spatter cone
-- ======================

local logfile = "C:\\Users\\Maarten\\OneDrive\\Desktop\\Netfabb Test\\Part_Rename_MJ.log"
system:logtofile(logfile)

function log(msg)
    system:log(msg)
end

function safe_pcall(f, ...)
    local ok, ret = pcall(f, ...)
    if ok then return ret end
    log("Error: " .. tostring(ret))
    return nil
end

-- Math Helpers
function dist_sq(p1, p2)
    return (p1.x - p2.x)^2 + (p1.y - p2.y)^2
end

function degrees_to_radians(deg)
    return deg * math.pi / 180.0
end

-- Spatter Area Check
-- Helper to check a single point against the cone
function is_point_in_spatter_cone(pt, source_bbox, angle_deg)
    -- 1. Must be below the source part (Y < source_min_y)
    if pt.y >= source_bbox.min.y then
        return false
    end

    local ang_rad = degrees_to_radians(angle_deg)
    local tan_a = math.tan(ang_rad)
    if tan_a < 0.001 then tan_a = 0.001 end

    local dy = source_bbox.min.y - pt.y
    local x_shift = dy / tan_a

    local x_limit_left = source_bbox.min.x - x_shift
    local x_limit_right = source_bbox.max.x + x_shift

    if pt.x > x_limit_left and pt.x < x_limit_right then
        return true
    end
    return false
end

-- Updated function checking the whole box
-- Checks if any corner of the candidate box is in the spatter cone of the source part
function is_box_in_spatter_area(cand_bbox, source_bbox, angle_deg)
    if not cand_bbox then return false end

    local corners = {
        {x=cand_bbox.min.x, y=cand_bbox.min.y},
        {x=cand_bbox.max.x, y=cand_bbox.min.y},
        {x=cand_bbox.min.x, y=cand_bbox.max.y},
        {x=cand_bbox.max.x, y=cand_bbox.max.y}
    }

    for _, pt in ipairs(corners) do
        if is_point_in_spatter_cone(pt, source_bbox, angle_deg) then
            return true
        end
    end
    return false
end

if not _G.tray then
    log("Error: No active tray. Run this script in Netfabb with an open project.")
    return
end

log("--- Starting Part_Rename_MJ ---")

-- 1. Collect Meshes from Active Tray
local meshes = {}
local mesh_count = safe_pcall(function() return tray.root.meshcount end) or 0

if mesh_count == 0 then
    log("No meshes found in active tray.")
    return
end

-- Helper function to safely get a property from a userdata/table
function safe_get(obj, key)
    if type(obj) ~= "userdata" and type(obj) ~= "table" then return nil end
    local ok, val = pcall(function() return obj[key] end)
    if ok then return val end
    return nil
end

-- Helper to normalize bounding box to {min={x,y}, max={x,y}}
function normalize_box(b)
    if not b then return nil end

    -- Pattern 1: .minx, .maxx
    local minx = safe_get(b, "minx")
    local maxx = safe_get(b, "maxx")
    local miny = safe_get(b, "miny")
    local maxy = safe_get(b, "maxy")

    if minx and maxx and miny and maxy then
        return { min={x=minx, y=miny}, max={x=maxx, y=maxy} }
    end

    -- Pattern 2: .min.x, .max.x
    local min = safe_get(b, "min")
    local max = safe_get(b, "max")
    if min and max then
        local mx = safe_get(min, "x")
        local my = safe_get(min, "y")
        local Mx = safe_get(max, "x")
        local My = safe_get(max, "y")
        if mx and my and Mx and My then
             return { min={x=mx, y=my}, max={x=Mx, y=My} }
        end
    end

    return nil
end

-- Helper function to robustly get bounding box and center
function get_mesh_info(m)
    local box = nil
    local center = nil

    -- Try Property: .outbox
    local ok, res = pcall(function() return m.outbox end)
    box = normalize_box(res)

    -- Try Method: :getOutbox() (CamelCase)
    if not box then
        local ok2, res2 = pcall(function() return m:getOutbox() end)
        box = normalize_box(res2)
    end

    -- Try Method: :getboundingbox()
    if not box then
        local ok3, res3 = pcall(function() return m:getboundingbox() end)
        box = normalize_box(res3)
    end

    if box then
        local cx = (box.min.x + box.max.x) / 2.0
        local cy = (box.min.y + box.max.y) / 2.0
        center = {x=cx, y=cy}
    else
        -- Fallback: .center property (sometimes available)
        local ok4, c = pcall(function() return m.center end)
        if ok4 and c then
            local cx = safe_get(c, "x")
            local cy = safe_get(c, "y")
            if cx and cy then
                center = {x=cx, y=cy}
                -- Fake bbox
                box = {min={x=cx, y=cy}, max={x=cx, y=cy}}
            end
        end
    end

    return box, center
end

for i = 0, mesh_count - 1 do
    local m = tray.root:getmesh(i)
    local box, center = get_mesh_info(m)

    if box and center then
        table.insert(meshes, {
            mesh = m,
            index = i,
            center = center,
            bbox = box,
            labelled = false,
            orig_name = safe_pcall(function() return m.name end) or "Unknown"
        })
    else
        log("Warning: Could not get BBox/Center for mesh index " .. i)
    end
end

log("Collected " .. #meshes .. " meshes.")

-- 2. Initialize
-- Start Point is Origin (0,0).
local current_pt = {x=0, y=0}
local current_bbox = nil -- No spatter from origin
local labelled_count = 0

-- 3. Loop until all parts labelled
while labelled_count < #meshes do
    local best_candidate = nil
    -- Initialize best_score.
    -- If minimizing (Pos Weights), init with Huge number.
    -- If maximizing (Neg Weights), init with Tiny number (-Huge).
    -- User said "smaller the better". So we assume we are looking for Min Value.
    local best_score = 1e30

    -- Determine if any candidate found
    local found_any = false

    for _, cand in ipairs(meshes) do
        if not cand.labelled then

            -- Calculate Variables

            -- Y Distance: abs(Candidate.y - Current.y)
            local y_dist = math.abs(cand.center.y - current_pt.y)

            -- Part Distance: Euclidean Distance
            local p_dist = math.sqrt(dist_sq(cand.center, current_pt))

            -- Spatter Area Check
            local is_spatter = false
            if current_bbox then
                -- Check if any corner of Candidate Box is in Spatter Area of Current Part
                is_spatter = is_box_in_spatter_area(cand.bbox, current_bbox, Spatter_Angle)
            end
            local spatter_val = is_spatter and 1.0 or 0.0

            -- Weighted Function
            local score = (Weight_Y_Distance * y_dist) +
                          (Weight_Part_Distance * p_dist) +
                          (Weight_Spatter_Area * spatter_val)

            -- Check Min
            if score < best_score then
                best_score = score
                best_candidate = cand
            end
            found_any = true
        end
    end

    if found_any and best_candidate then
        -- Rename
        -- Format: 000_Name, 001_Name...
        local new_name = string.format("%03d_%s", labelled_count, best_candidate.orig_name)

        -- Apply Rename
        -- Use standard pcall because assignment returns nil (which safe_pcall would treat as error/ambiguous)
        local ok, err = pcall(function() best_candidate.mesh.name = new_name end)

        if ok then
            log(string.format("Renamed '%s' -> '%s' (Score=%.2f, Y_Dist=%.2f, Dist=%.2f, Spatter=%s)",
                best_candidate.orig_name, new_name, best_score,
                math.abs(best_candidate.center.y - current_pt.y),
                math.sqrt(dist_sq(best_candidate.center, current_pt)),
                tostring(is_box_in_spatter_area(best_candidate.bbox, current_bbox or {min={x=0,y=0},max={x=0,y=0}}, Spatter_Angle))
            ))

            best_candidate.labelled = true
            labelled_count = labelled_count + 1

            -- Update Current Pointer
            current_pt = best_candidate.center
            current_bbox = best_candidate.bbox
        else
            log("Error renaming part " .. best_candidate.orig_name .. ": " .. tostring(err))
            break
        end
    else
        log("No more candidates found (or logic error).")
        break
    end
end

log("Part Rename Complete.")
