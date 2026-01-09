
-- LUA Script for Autodesk Netfabb (2021.0)
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes only
--==============================================================================

-- This script exports all supported parts in a tray.
-- The closed support will be merged with the part and will be exported as "partname" + "partextension".stl
-- The open support will be exported as "partname" + "supportextension".stl
-- This script is very usefull in cases where the parts should be printed on EOS or SLM machines.

partextension = '_p'
supportextension = '_0m'

system:executescriptfile ("Examples\\\\LUA Scripts\\\\BaseRoutines.lua");

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

system:logtofile ('LUAoutput.txt');
system:setloggingtooglwindow(true);
local outputdir = system:showdirectoryselectdialog(false, false, false);
if outputdir == "" then
   return;
end
outputdir = outputdir .. "\\\\"
if tray == nil then
    system:log('  tray is nil!');
  else
    local root = tray.root;
    -- Collect meshes in the tray
    local meshes = {};
    insertMeshesIntoTable(root, meshes);

    -- Iterate meshes in group
    for i, traymesh in pairs(meshes) do
      if traymesh.hassupport then
         local luamesh   = traymesh.mesh;
         local partmesh = traymesh:createsupportedmesh(true, false, true);
         partmeshmesh = partmesh.mesh;
         partmeshmesh:unify(0.05);
         local supportmesh = traymesh:createsupportedmesh(false, true, false);
         local partname = outputdir .. traymesh.name .. partextension .. '.stl'
         local supportname = outputdir .. traymesh.name .. supportextension .. '.stl'
         partmeshmesh:savetostl(partname)
         supportmesh:savetostl(supportname)
      end;
    end;
    system:messagedlg("Meshes and Supports created.")
end;