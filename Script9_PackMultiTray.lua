-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable netfabbapplication is predefined and corresponds to current netfabb application.  
-- The variables allows to access every tray and to create new trays. 
-- takes the part from the first build platform and packs into the two other ones
-- The script will not run, if not three build platforms are already available.


system:setloggingtooglwindow(true);

function packtray(Actualtray) 

  local options = system:createstringmap();

  local pa_id = Actualtray.packingid_montecarlo;
  local packer = Actualtray:createpacker(pa_id);

  local params = { };
  local max_len = { 0, 0, 0, 0 };

  -- set some of the additional parameters if the null packer is used

  if pa_id == Actualtray.packingid_montecarlo then
    system:log('Setting options in the Monte Carlo packer.');
    packer.packing_quality = -1;
    packer.z_limit  = 0.0;    -- If z_limit is set to zero, the default value, MachineSizeZ will be used
    packer.start_from_current_positions = false;
  end;

  packer:pack();
  Actualtray:updatetodesktop();
end;


system:log('Get things started');
local trayArray = {};
system:log('Tray is here');
if (netfabbtrayhandler.traycount == 1) then
   netfabbtrayhandler:addtray('tray2', 400,400,400);
   netfabbtrayhandler:addtray('tray3', 400,400,400);
end;
if (netfabbtrayhandler.traycount > 2) then
   for idx = 0, netfabbtrayhandler.traycount - 1 do 
      trayArray[idx] = netfabbtrayhandler:gettray(idx);
   end;
   root    = trayArray[0].root;
   root2   = trayArray[1].root;
   root3   = trayArray[2].root;
   
   
   for mesh_index    = 0, root.meshcount - 1 do 
     local traymesh      = root:getmesh(mesh_index);
     local luamesh   = traymesh.mesh;   
     if  (mesh_index - math.floor(mesh_index/2)*2) == 0 then         
         root2:addmesh(luamesh);
      else 
         root3:addmesh(luamesh);
      end;
   end;
   packtray(trayArray[1]);
   packtray(trayArray[2]);
end;

                  


