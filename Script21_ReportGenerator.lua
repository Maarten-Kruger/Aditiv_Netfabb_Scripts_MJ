-- LUA Script for Autodesk Netfabb 2019.1
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- The scripts shows how to generate reports for parts in the tray


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

function createReportsForMeshesInTray(traypar)
    root = traypar.root;
    local meshes = {};
    insertMeshesIntoTable(root, meshes);
    local snapshot = system:createsnapshotcreator();
    local reportgenerator = system:createreportgenerator(snapshot);
    for i, traymesh in pairs(meshes) do
       reportgenerator:createreportformesh(traymesh, 'Reports\\netfabb_Part_Analysis.odt', 'D:\\LUAReport' .. tostring(i) ..'.odt');
    end;
    return true;
end;

function createReportForTray(traypar)
   local snapshot = system:createsnapshotcreator();
   local reportgenerator = system:createreportgenerator(snapshot);
   --reportgenerator:createreportfortray(tray, 'Reports\\netfabb_Platform_Views.odt', 'D:\\LUAReportPlatform.odt');
   reportgenerator:createreportfortray(tray, 'Reports\\quote.prpt',  'D:\\PlatformQuote.pdf');
   return true;
end;

if tray == nil then
    system:log('  tray is nil!');
  else
   createReportsForMeshesInTray(tray);
   createReportForTray(tray);
end;        