-- LUA Script for Autodesk Netfabb 2019.1
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Goes through the meshes in the tray and labels them


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

GPosX = 0;
GPosY = 0;
GPosZ = 0;

function SimpleEstimatePos(outbox, dir)
-- This is a helper function for estimating the position from the outbox
-- it supports the 6 planes of the cube and follows the ADSK view cube naming

   if dir == 'left' then
     GPosX = outbox.minx;
     GPosY = (outbox.miny + outbox.maxy) / 2;
     GPosZ = (outbox.minz + outbox.maxz) / 2;
     result = true;
   end;
   if dir == 'right' then
     GPosX = outbox.maxx;
     GPosY = (outbox.miny + outbox.maxy) / 2;
     GPosZ = (outbox.minz + outbox.maxz) / 2;
     result = true;
   end;
   if dir == 'top' then
     GPosX = (outbox.minx + outbox.maxx) / 2.0;
     GPosY = (outbox.miny + outbox.maxy) / 2.0;
     GPosZ = outbox.maxz;
     result = true;
   end;
   if dir == 'bottom' then
     GPosX = (outbox.minx + outbox.maxx) / 2.0;
     GPosY = (outbox.miny + outbox.maxy) / 2.0;
     GPosZ = outbox.minz;
     result = true;
   end;
   if dir == 'front' then
     GPosX = (outbox.minx + outbox.maxx) / 2.0;
     GPosY = outbox.miny;
     GPosZ = (outbox.minz + outbox.maxz) / 2;
     result = true;
   end;
   if dir == 'back' then
     GPosX = (outbox.minx + outbox.maxx) / 2.0;
     GPosY = outbox.maxy;
     GPosZ = (outbox.minz + outbox.maxz) / 2;
     result = true;
   end;
end;


function SetSimpleStamperSettings(stamperpar, PosX, PosY, PosZ, dir)
-- This is a helper function for settings the label settings
-- it supports the 6 planes of the cube and follows the ADSK view cube naming

      local result = false;
      stamperpar:setpos(PosX,PosY,PosZ);
      if dir == 'left' then
        stamperpar:setnormal(-1,0,0);
        stamperpar:setupvector(0,0,-1);
        result = true;
      end;
      if dir == 'right' then
        stamperpar:setnormal(1,0,0);
        stamperpar:setupvector(0,0,-1);
        result = true;
      end;
      if dir == 'bottom' then
        stamperpar:setnormal(0,0,-1);
        stamperpar:setupvector(0,1,0);
        result = true;
      end;
      if dir == 'top' then
        stamperpar:setnormal(0,0,1);
        stamperpar:setupvector(0,1,0);
        result = true;
      end;
      if dir == 'front' then
        stamperpar:setnormal(0,-1,0);
        stamperpar:setupvector(0,0,-1);
        result = true;
      end;
      if dir == 'back' then
        stamperpar:setnormal(0,1,0);
        stamperpar:setupvector(0,0,-1);
        result = true;
      end;
      return result;
end;
 
system:setloggingtooglwindow(true);

if tray == nil then
    system:log('  tray is nil!');
  else
    local root = tray.root; 
    -- Collect meshes in the tray
    local meshes = {};
    insertMeshesIntoTable(root, meshes);
    
    -- Iterate meshes in group
    local stamper = system:createstamper();
    stamper.depth = 2;
    stamper.height = 20;
    stamper.issubtracted = true;
      
    for i, traymesh in pairs(meshes) do  
      local luamesh   = traymesh.mesh;
      luamesh:applymatrix(traymesh.matrix);
      local outbox = luamesh:calcoutbox();
      SimpleEstimatePos(outbox, 'front');
      SetSimpleStamperSettings(stamper, GPosX, GPosY, GPosZ, 'front');

      local newmesh = stamper:stamp(luamesh, 'Mylabel' .. tostring(i));
      root:addmesh(newmesh);
    end;  
end;  
      
    
