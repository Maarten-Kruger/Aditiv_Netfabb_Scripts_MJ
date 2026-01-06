-- LUA Script for Autodesk Netfabb 2022.0
-- Copyright by Autodesk 2021
-- This script is for demonstration purposes
--==============================================================================

-- The script shows the usages of external programmes
-- Microsoft Powerpoint needs to be installed 

system:setloggingtooglwindow(true);

local saveFileDir = application:getappdatadirectory();
saveFileDir = saveFileDir .. "\\Netfabb\\Report3mf";
application:createfolder(saveFileDir);


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
      local matrix   = traymesh.matrix;
      luamesh:applymatrix(matrix);
      local meshname =  saveFileDir .. "\\" .."file" .. tostring(i) .. ".3mf";
      luamesh:saveto3mf(meshname);
      distort_batch_file = system:createtextfile();
      distort_batch_file:writeline("Name: " .. traymesh.name);
      distort_batch_file:writeline("Facecount: " .. luamesh.facecount);
      local outbox = traymesh:calcoutbox();
      distort_batch_file:writeline("Height: " .. outbox.maxz - outbox.minz .. " mm");
      if (luamesh.isok) then
        distort_batch_file:writeline("Mesh is ok");
      else
        distort_batch_file:writeline("Mesh is not ok");
      end;
      distort_batch_file:savetofile(saveFileDir .. "\\" .."file" .. tostring(i) ..".txt");
    end;
end;
local pathPptm = saveFileDir .. "\\Demo3mf.pptm";
local cmdstringcopy = "/c copy \".\\Examples\\Lua Scripts\\Demo3mf.pptm\" "..saveFileDir.."\"";
system:shellexecute('cmd', cmdstringcopy,1,1);

local cmdstring = "/c powerpnt /M \""..pathPptm.." \"  main";
system:shellexecute('cmd', cmdstring,1,1, "C:\\Program Files (x86)\\Microsoft Office\\root\\Office16");
