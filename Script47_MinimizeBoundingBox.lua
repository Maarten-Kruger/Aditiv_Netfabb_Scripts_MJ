-- LUA Script for Autodesk Netfabb 2025.0
-- Copyright by Autodesk 2023
-- This script is for demonstration purposes
--==========================================
-- This scrip demonstrate minimize bounding box 
-- (bounding box is called in Lua outbox) 
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
    for i, mesh in pairs(meshes) do
      group = mesh.parent

      local luamesh  = mesh.mesh;
      luamesh:applymatrix(mesh.matrix);

      -- Minimize Outbox Options
      -- 1) Volume
      -- 2) VolumeFlat
      -- 3) HeightBase
      luamesh:minimizeoutbox('Volume');

      -- Creates a new mesh
      newmesh = group:addmesh(luamesh)
      -- copies the mesh name from old mesh to new mesh
      newmesh.name = mesh.name
      -- copies the mesh color from old mesh to new mesh
      newmesh.color = mesh.color
      -- Remove the old mesh
      removemesh = group:removemesh(mesh)

    end;
end;
