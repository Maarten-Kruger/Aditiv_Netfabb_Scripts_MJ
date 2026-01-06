-- LUA Script for Autodesk Netfabb 2021.0
-- Copyright by Autodesk 2020
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

function colorMeshBasedOnArray(mesh, array, threshold, colortype)
  for j=0, array.length -1 do
    if tonumber(array:get(j)) < threshold then
      if colortype == 'red' then
        mesh:colortriangle(j,0,0,255,254);
      end;

      if colortype == 'green' then
        mesh:colortriangle(j,0,255,0,254);
      end;

      if colortype == 'blue' then
        mesh:colortriangle(j,255,0,0,254);
      end;
    end;
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
      local array = system:createarray();
      newMesh:colortriangles(128,128,128,128);
      xmlResult = newMesh:wallthicknesstestwithoutput(0.51,10, false, true, array);
      colorMeshBasedOnArray(newMesh, array, 0.51, 'red');

      newMesh:featuredetection(0.51,10,false, true, array);
      colorMeshBasedOnArray(newMesh, array, 0.51, 'blue');
      newtraymesh = root:addmesh(newMesh);
      newtraymesh.name = "0.51 mm threshold";
    end;
end;                