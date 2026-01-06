-- LUA Script for Autodesk Netfabb 2019.1
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Goes through the meshes in the tray and repair them if its necessary

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
    -- Get root meshgroup from tray
    local root = tray.root;

    -- Collect meshes in the tray
    local meshes = {};
    insertMeshesIntoTable(root, meshes);

    -- Iterate over meshes in tray
    for i, traymesh in pairs(meshes) do   
      local luamesh   = traymesh.mesh;      
      newMesh = luamesh:dupe();
      local matrix   = traymesh.matrix;
      newMesh:applymatrix(matrix);
      newMesh:featuredetection(0.5,1,true);
      newtraymesh = root:addmesh(newMesh);
      newtraymesh.name = traymesh.name .. " 0.5 mm threshold";
    end;  
end; 