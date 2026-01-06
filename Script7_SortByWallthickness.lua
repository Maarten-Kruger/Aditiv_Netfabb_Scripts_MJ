-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Adds files from a directory to the current tray 


system:setloggingtooglwindow(true);
if (tray ~= nil) then
  -- Get root meshgroup from tray
  local root = tray.root;
  -- Iterate meshes in group
  for mesh_index    = 0, root.meshcount - 1 do  
    local traymesh      = root:getmesh(mesh_index);
    local luamesh   = traymesh.mesh;
    local matrix   = traymesh.matrix;
    newMesh = luamesh:dupe();
    newMesh:applymatrix(matrix);
    ThicknessTd = 0.35;  --[mm] Wallthickness threshold, everything below is regarded as too thin 
    AreaTd = 10;         --[%] critical area in percent of the total area
    testPassed = newMesh:wallthicknesstest(ThicknessTd,AreaTd);
    if not testPassed then
      if not system:directoryexists('failed') then
        system:createdirectory('failed');
      end;
         newMesh:savetostl('failed/ ' .. traymesh.name.. '.stl');
    else
       if not system:directoryexists('passed') then
        system:createdirectory('passed');
       end;
         newMesh:savetostl('passed/ ' .. traymesh.name.. '.stl');
    end;     
  end;
end;  
 

