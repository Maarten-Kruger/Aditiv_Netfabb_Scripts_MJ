-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Creates a new subgroup, and copies all existing meshes into it

if tray == nil then
    system:log('  tray is nil!');
  else
    -- Get root meshgroup from tray
    local root = tray.root;
    -- Iterate meshes in group
    local meshes = {};
    for mesh_index    = 0, root.meshcount - 1 do  
      local traymesh      = root:getmesh(mesh_index);
      table.insert(meshes, traymesh);
    end;
    
    local subgroup = root:addsubgroup('SpecialName');
    for i, traymesh in pairs(meshes) do    
      newmesh = subgroup:addmesh(traymesh.mesh);
      newmesh.name = traymesh.name;
    end;
end;
