-- LUA Script for Autodesk Netfabb 2019.1
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Cuts the meshes in the tray.


system:setloggingtooglwindow(true);
 
local insertMeshesIntoTable;
insertMeshesIntoTable = function (meshgroup, Outtable)
  for mesh_index    = 0, meshgroup.meshcount - 1 do  
      local traymesh      = meshgroup:getmesh(mesh_index);
      table.insert(Outtable, traymesh);
  end;
  for group_index = 0, meshgroup.groupcount - 1 do  
     subgroup = meshgroup:getsubgroup(group_index);
     insertMeshesIntoTable(subgroup, Outtable);
  end;
end; 

if tray == nil then
    system:log('  tray is nil!');
  else
    local root = tray.root; 
    -- Collect meshes in the tray
    local meshes = {};
    insertMeshesIntoTable(root, meshes);
    
    -- Iterate meshes in group
    for i, traymesh in pairs(meshes) do  
      local luamesh   = traymesh.mesh;
      local matrix   = traymesh.matrix;
      newMesh = luamesh:dupe();
      newMesh:applymatrix(matrix);
      local cuttedmesh = newMesh:cut(2,20); --First Parameter: 0:y-z Plane, 1: x-y plane, 2: x-y Plane; Second Parameter: position of the plane in [mm]
      root:addmesh(cuttedmesh);
    end;  
end;   