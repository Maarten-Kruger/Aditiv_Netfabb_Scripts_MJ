-- LUA Script for Autodesk Netfabb 2021.1
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes only
--==============================================================================

-- This script shows how to access the physics packer from a LUA script

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


function loadfile (filename)
  path,file,ext = string.match(filename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
  ext = ext:lower()
  if ext == "stl" then
  	return system:loadstl (filename)
  elseif ext == "3ds" then
  	return system:load3ds (filename)
  elseif ext == "3mf" then
  	return system:load3mf(filename)
  elseif ext == "amf" then
  	return system:loadamf(filename)
  elseif ext == "gts" then
  	return system:loadgts(filename)
  elseif ext == "ncm" then
  	return system:loadncm(filename)
  elseif ext == "obj" then
  	return system:loadobj(filename)
  elseif ext == "ply" then
  	return system:loadply(filename)
  elseif ext == "svx" then
  	return system:loadvoxel(filename)
  elseif ext == "vrml" then
  	return system:loadvrml(filename)
  elseif ext == "wrl" then
  	return system:loadvrml(filename)
  elseif ext == "x3d" then
  	return system:loadx3d(filename)
  elseif ext == "x3db" then
  	return system:loadx3d(filename)
  elseif ext == "zpr" then
    return system:loadzpr(filename)
  else
  	return nil
  end
end;

fabbproject = system:newfabbproject();
system:log(fabbproject.traycount);
xmlfilelist = system:getallfilesindirectory('d:\\temp'); --Insert here your directory
system:log(xmlfilelist.childcount);

numberoffiles = xmlfilelist.childcount;
if fabbproject.traycount > 0 then
   local ltray = fabbproject:gettray(0);
   local root = ltray.root;
   for i=0,numberoffiles-1 do
     xmlChild = xmlfilelist:getchildindexed(i);
     filename = xmlChild:getchildvalue ("filename");
     path,file,ext = string.match(filename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
     mesh = loadfile(filename);
     if mesh ~= nil then
       local traymesh = root:addmesh(mesh);
       system:log(file);
       traymesh.name = file;
     end;
   end;
   local meshes = {};
   insertMeshesIntoTable(root, meshes);

   -- Iterate over meshes in tray
   for i, traymesh in pairs(meshes) do
     local luamesh   = traymesh.mesh;
     if not luamesh.isok then
       newMesh = luamesh:dupe();
       local matrix   = traymesh.matrix;
       newMesh:repairsimple();
       newMesh:applymatrix(matrix);
       nameStored = traymesh.name;
       root:removemesh(traymesh);
       newTrayMesh = root:addmesh(newMesh);
       newTrayMesh.name = nameStored;
     end;
   end;
   fabbproject:savetofile('d:\\test0.fabbproject');
end;
                           