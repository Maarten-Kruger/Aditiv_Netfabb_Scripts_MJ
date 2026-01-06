-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script demonstrates an advanced packing scenario
-- One can use different packing distances for different parts

-- The script does the following:
-- seperate parts by volume into two groups
-- assign two different external offsets to parts per group (=part distance)
-- pack resulting parts (ghost parts)
-- substitute parts for originals

-- Please note that the ghost parts are need to be removed manually

system:setloggingtooglwindow(true);

volumeThreshold = 1000;

function MoveMatrixZ(matrix, value)
  local tmp = matrix:get(2,2)
  matrix:set(3, 2, tmp + value);

end;

function getVolumeOfmesh(meshPar)
  local luamesh   = meshPar.mesh;
  local matrix   = meshPar.matrix;
  luamesh:applymatrix(matrix);
  return luamesh.volume;
end;

function GenerateOffsetOfmesh(meshPar, offset)
  local luamesh   = meshPar.mesh;
  local matrix   = meshPar.matrix;
  luamesh:applymatrix(matrix);
  local newmesh = luamesh:offset(offset,offset / 3.0, true, false);
  return newmesh;
end;

function PrintMatrix(matrix)
  system:log(matrix:get(0,0)..' '..matrix:get(0,1)..' '..matrix:get(0,2)..' '..matrix:get(0,3));
  system:log(matrix:get(1,0)..' '..matrix:get(1,1)..' '..matrix:get(1,2)..' '..matrix:get(1,3));
  system:log(matrix:get(2,0)..' '..matrix:get(2,1)..' '..matrix:get(2,2)..' '..matrix:get(2,3));
  system:log(matrix:get(3,0)..' '..matrix:get(3,1)..' '..matrix:get(3,2)..' '..matrix:get(3,3));
end;

OffsetLarge = 5;
OffsetSmall = 0.5;

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

if tray == nil then
    system:log('  tray is nil!');
  else
    local root = tray.root;

    local meshesPre = {};
    local meshesOrig = {};
    local meshesOffset = {};
    local matrixOrig = {};
    local OffsetCorr = {};

    local meshesOffset = {};
    for mesh_index    = 0, root.meshcount - 1 do
      local traymesh = root:getmesh(mesh_index);
      table.insert(meshesPre, traymesh);
    end;

    system:log('meshesPre '..tablelength(meshesPre));
    for i, traymesh in pairs(meshesPre) do
       local luamesh = traymesh.mesh;
       local matrix = traymesh.matrix;
       luamesh:applymatrix(matrix);
       --root:removemesh(traymesh);
       table.insert(meshesOrig, root:addmesh(luamesh));
    end;

    for i, traymesh in pairs(meshesPre) do
       root:removemesh(traymesh);
    end;



   system:log('Generate Offset');
   for i, traymesh in pairs(meshesOrig) do
      if (getVolumeOfmesh(traymesh) > volumeThreshold) then
         local newmesh = GenerateOffsetOfmesh(traymesh, OffsetLarge);
         local newtraymesh = root:addmesh(newmesh);
         newtraymesh:setpackingoption('restriction', 'norestriction');
         table.insert(meshesOffset, newtraymesh);

         table.insert(OffsetCorr, OffsetLarge);
         system:log('large');
      else
         local newmesh = GenerateOffsetOfmesh(traymesh, OffsetSmall);
         local newtraymesh = root:addmesh(newmesh);
         newtraymesh:setpackingoption('restriction', 'norestriction');
         table.insert(meshesOffset, newtraymesh);
         table.insert(OffsetCorr, OffsetSmall);
         system:log('small');
      end;
   end;


   system:log('Move Old meshes from the buildplatform');
   for i, traymesh in pairs(meshesOrig) do
     local matrix = traymesh.matrix;
     MoveMatrixZ(matrix, 1000);
     traymesh:setmatrix(matrix);
     traymesh:setpackingoption('restriction', 'locked');
   end;


   system:log('Pack');
   local packer = tray:createpacker(tray.packingid_montecarlo);
   -- Please note that the createpacker command creates a snapeshoot of the
   -- tray with its current parts. If parts are removed or added afterwards 
   -- you need to create a new packer
   packer.packing_quality = -1;
   packer.z_limit  = 0.0;
   packer.start_from_current_positions = false;
   packer:pack();

   system:log('Move orig parts to places');
   for i, traymesh in pairs(meshesOrig) do
    local packedMesh = meshesOffset[i];
    traymesh:setmatrix(packedMesh.matrix);
    local offset = OffsetCorr[i];
   end;

   system:log('remove offset parts');
   for i, traymesh in pairs(meshesOffset) do
      local Mesh = meshesOffset[i];
      root:removemesh(Mesh); 
   end;



end;
