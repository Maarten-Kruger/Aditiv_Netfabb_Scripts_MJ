-- LUA Script for Autodesk Netfabb 2021.1
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Gets the coordinates of a triangle and colors the triangle based on the z coordinate


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

function getcolorMeshs(mesh)
  node1 = system:createvector4();
  node2 = system:createvector4();
  node3 = system:createvector4();
  for j=0, mesh.facecount -1 do
    mesh:getcolortriangle(j,node1,node2,node3);
    system:log(node1.w);
    system:log(node1.x);
    system:log(node1.y);
    system:log(node1.z);
  end;
end;

function ColorBasedZHeightOfFace(mesh)
  node1 = system:createvector3();
  node2 = system:createvector3();
  node3 = system:createvector3();
  for j=0, mesh.facecount -1 do
    mesh:getnodepositionofface(j,node1,node2,node3);
    local height = (node1.z + node2.z + node3.z) / 3;
    if ((math.floor(height) % 2) == 0) then
       mesh:colortriangle(j,255,0,0);
    else
       mesh:colortriangle(j,0,0,255);
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
      ColorBasedZHeightOfFace(newMesh);
      root:addmesh(newMesh);
    end;
end;       