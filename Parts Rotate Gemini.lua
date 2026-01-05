-- Get the total number of parts in the project
local partCount = system.getPartCount()

for i = 0, partCount - 1 do
    local part = system.getPart(i)
    
    if part then
        -- Calculate the center of the part's bounding box
        local outbox = part:getOutbox()
        local centerX = (outbox.min.x + outbox.max.x) / 2
        local centerY = (outbox.min.y + outbox.max.y) / 2
        local centerZ = (outbox.min.z + outbox.max.z) / 2
        
        -- Rotate the part 90 degrees around its center
        -- Parameters: (pivotX, pivotY, pivotZ, axisX, axisY, axisZ, angleInDegrees)
        -- Using 0, 0, 1 for the axis performs a rotation around the Z-axis
        part:rotate(centerX, centerY, centerZ, 0, 0, 1, 90)
    end
end

system.log("Successfully rotated " .. partCount .. " parts by 90 degrees.")