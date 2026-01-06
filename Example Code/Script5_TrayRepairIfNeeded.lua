-- Lua Script for Autodesk Netfabb 2025
-- Copyright by Autodesk 2024
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the Lua Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Goes through the meshes in the tray and repair them if its necessary


system:setloggingtooglwindow(true);

local insertMeshesIntoTable;
local meshcount = 0;
insertMeshesIntoTable = function (meshgroup, Outtable)
  for mesh_index    = 0, meshgroup.meshcount - 1 do
      local traymesh      = meshgroup:getmesh(mesh_index);
      table.insert(Outtable, traymesh);
      meshcount = meshcount + 1;
  end;
  for group_index = 0, meshgroup.groupcount - 1 do
     subgroup = meshgroup:getsubgroup(group_index);
     insertMeshesIntoTable(subgroup, Outtable);
  end;
end;

if tray == nil then
    system:log('There is no tray!');
  else
    -- Get root meshgroup from tray
    local root = tray.root;

    -- Collect meshes in the tray
    local meshes = {};
    insertMeshesIntoTable(root, meshes);

    -- Iterate over meshes in tray
    system:showprogressdlgcancancel(true);
    for i, traymesh in pairs(meshes) do
      local luamesh   = traymesh.mesh;
      system:setprogresscancancel(100*i/meshcount, 'Repairing part:' .. traymesh.name, false);
      if not luamesh.isok then
        newMesh = luamesh:dupe();
        local matrix   = traymesh.matrix;
        newMesh:repairenhanced();
        if newMesh.isok then
          local newname = traymesh.name .. ' (default repair)';
          newMesh:applymatrix(matrix);
          root:removemesh(traymesh);
          root:addmesh(newMesh, newname);
        else
          local newname = traymesh.name .. ' (extended repair)';
          newMesh = luamesh:dupe();
          newMesh:repairextended();
          newMesh:applymatrix(matrix);
          root:removemesh(traymesh);
          root:addmesh(newMesh, newname);
        end;
      end;
      isCancel = system:progresscancelled();
      if isCancel then                      -- Defines cancel behaviour
         system:log('Automation canceled during Phase 1: Repairing parts');
         break;
      end;
   end;
    system:hideprogressdlgcancancel();
end;
