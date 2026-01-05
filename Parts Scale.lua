-- Netfabb Lua Script: Scale Selected Parts by 50%
-- This script reduces the size of selected parts to half of their current dimensions.

-- 1. Retrieve the list of parts currently selected in the project
local selectedParts = system.getselectedparts()

-- 2. Check if any parts are selected to avoid errors
if #selectedParts == 0 then
    system.log("No parts selected. Please select at least one part to scale.")
else
    -- 3. Iterate through each selected part and apply the scale
    for i = 1, #selectedParts do
        local part = selectedParts[i]
        
        -- The scale method takes (X, Y, Z) factors. 0.5 = 50%
        part:scale(0.5, 0.5, 0.5)
        
        -- Log the action to the Netfabb console
        system.log("Scaled part: " .. part.name .. " to 50% size.")
    end
end