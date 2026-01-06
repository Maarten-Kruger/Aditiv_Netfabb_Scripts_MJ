-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Packs the current tray with an additional feature:
-- All large parts are packed in the center of the build room

function checkErrorCodeMCpacker(errorcodepar)

    if errorcodepar == 0 then
        system:log('Monte Carlo Packing is finished. No problems were detected.');
    elseif errorcodepar == 1 then
        system:log('Monte Carlo Packing is finished. There is not enough place for all parts in the tray.');
    elseif errorcodepar == 2 then
        system:log('Monte Carlo Packing is finished. Some parts are too large for the given tray.');
    elseif errorcodepar == 3 then
        system:log('Monte Carlo Packing failed: All parts are too large for the given tray.');
    elseif errorcodepar == 4 then
        system:log('Monte Carlo Packing failed: There are no parts to pack.');
    elseif errorcodepar == 5 then
        system:log('Monte Carlo Packing failed: Starting from current positions is not possible.');
    else
        system:log('Monte Carlo Packing failed: Unknown error. ');
    end;
end;

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

system:logtofile ('LUAoutput.txt');
system:setloggingtooglwindow(true);


local pa_id = tray.packingid_montecarlo;

local packer = tray:createpacker(pa_id);
local outboxOrig = packer:getoutbox();
local outbox = packer:getoutbox();

local tempMaxX = outbox.maxx;
local tempMaxY = outbox.maxy;

outbox.minx = 100; --For the first packing we reduce the packer area
outbox.miny = 100;

outbox.maxx = tempMaxX - 100;
outbox.maxy = tempMaxY - 100;

packer:setoutbox(outbox);


volumeThreshold = 10000; --Cubic mm, the volume threshold, everything higher is considered as large and is packed in the center

if pa_id == tray.packingid_montecarlo then
  -- Setting options in the Monte Carlo packer
  packer.packing_quality = -1;
  packer.z_limit  = 0.0;    -- If z_limit is set to zero, the default value, MachineSizeZ will be used
  packer.start_from_current_positions = false; 
end;

if tray == nil then
  system:log('  tray is nil!');
else
  local root = tray.root;
  local meshesOrig = {};
  for mesh_index    = 0, root.meshcount - 1 do
    local traymesh = root:getmesh(mesh_index);
    table.insert(meshesOrig, traymesh);
  end;
  --All meshes above the buildplatform
  system:log('Move Old meshes from the buildplatform');
  for i, traymesh in pairs(meshesOrig) do
    local matrix = traymesh.matrix;
    MoveMatrixZ(matrix, 1000);
    traymesh:setmatrix(matrix);
  end;
  for i, traymesh in pairs(meshesOrig) do
    if (getVolumeOfmesh(traymesh) > volumeThreshold) then
      traymesh:setpackingoption('restriction', 'norestriction');
    else
      traymesh:setpackingoption('restriction', 'locked');
    end;
  end;
  --Pack large things
 local errorcode=packer:pack();

  --Now pack small things
  packer:setoutbox(outboxOrig);
  for i, traymesh in pairs(meshesOrig) do
    if (getVolumeOfmesh(traymesh) < volumeThreshold) then
      traymesh:setpackingoption('restriction', 'norestriction');
    else
      traymesh:setpackingoption('restriction', 'locked');
    end;
  end;
  local errorcode=packer:pack();
  checkErrorCodeMCpacker(errorcode);
end;





