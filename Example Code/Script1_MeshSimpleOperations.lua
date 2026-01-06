-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Loads and manipulates the current tray from the desktop application 

  
--system:logtofile ('LUAoutput.txt');  -- Here we assume that you have the right to write the file. 
                                     -- Otherwise a access denied warning will pop up

system:setloggingtooglwindow(true);
--system:logtofile ('d:\\demo\\LUAoutput.txt');  --Example with path, we need to have two backslashes due to the parsing of LUA


if tray == nil then
    system:log('  tray is nil!');
  else
    -- Get root meshgroup from tray
    local root = tray.root;
    system:log('  tray with ' .. tostring(root.meshcount) .. ' meshes');
    -- Iterate meshes in group
    for mesh_index    = 0, root.meshcount - 1 do
      
      local translate = 150;
      local scale     = 0.5;
      local mesh      = root:getmesh(mesh_index);
      local luamesh   = mesh.mesh;
     
      -- translate mesh
      mesh:translate(translate, 0, translate);
      mesh:scale(scale, scale, scale);
    end;  
end;
      
    