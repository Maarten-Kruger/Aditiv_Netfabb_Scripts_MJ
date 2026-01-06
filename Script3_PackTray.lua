-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Packs the current tray  


system:setloggingtooglwindow(true);

local options = system:createstringmap();

--local pa_id = tray.packingid_outbox;
local pa_id = tray.packingid_montecarlo;

--local pa_id = tray.packingid_2d;
local packer = tray:createpacker(pa_id);
-- Please note that the createpacker command creates a snapeshoot of the
-- tray with its current parts. If parts are removed or added afterwards 
-- you need to create a new packer
   
local params = { };
local max_len = { 0, 0, 0, 0 };

-- set some of the additional parameters if the null packer is used

if pa_id == tray.packingid_montecarlo then
  -- Setting options in the Monte Carlo packer
  packer.packing_quality = -1;
  packer.z_limit  = 0.0;    -- If z_limit is set to zero, the default value, MachineSizeZ will be used
  packer.start_from_current_positions = false; 
 end;

if pa_id == tray.packingid_2d then
  -- Setting options in the two packer
  packer.rastersize = 1; -- Named "Voxelsize" in the 2d packer GUI Element 
  packer.anglecount = 7; -- Named "Zrotation" steps in the 2d packer GUI Element 
  packer.coarsening = 1; -- Named "Accuracy"  in the 2d packer GUI Element
  packer.placeoutside = true;      -- Named "Place non-fitting Parts outside Platform" in the 2d packer GUI Element
  packer.packonlyselected = false;
  packer.borderspacingxy = 0;
end;
 
 if pa_id == tray.packingid_outbox then
  -- Setting options in the two packer
  packer.rastersize = 1;
  packer.minimaldistance = 2;
  packer.pack2D = false;  

end;

local errorcode=packer:pack();
if pa_id == tray.packingid_montecarlo then
    if errorcode == 0 then
        system:log('Monte Carlo Packing is finished. No problems were detected.');
        saveproject=true;
    elseif errorcode == 1 then
        system:log('Monte Carlo Packing is finished. There is not enough place for all parts in the tray.');
        saveproject=true;
    elseif errorcode == 2 then
        system:log('Monte Carlo Packing is finished. Some parts are too large for the given tray.');
        saveproject=true;
    elseif errorcode == 3 then
        system:log('Monte Carlo Packing failed: All parts are too large for the given tray.');
    elseif errorcode == 4 then
        system:log('Monte Carlo Packing failed: There are no parts to pack.');
    elseif errorcode == 5 then
        system:log('Monte Carlo Packing failed: Starting from current positions is not possible.');
    else
        system:log('Monte Carlo Packing failed: Unknown error. Please contact the support team.');
    end;
else
    system:log('packer returns error code ' .. tostring(errorcode));
end;

