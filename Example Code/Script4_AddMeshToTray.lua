-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Adds a mesh to the current tray 

 

meshloaded = system:load3mf('Examples\\LatticeCommander\\Bracket.3mf');

if tray == nil then
  system:log('  tray  is nil!');
else
  -- Get root meshgroup from tray
  local root = tray.root;
  root:addmesh(meshloaded);
end;
      
    