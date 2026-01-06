-- LUA Script for Autodesk Netfabb
-- Copyright by Autodesk 2021
-- This script is for demonstration purposes
--==============================================================================

-- This script shows how to call a function in the "generic" demo engine

-- The UUID of the workspace, defined in the uuid tag of the "workspacedefinition" node 
-- of the provided "workspaces_extra.xml" (or "workspaces.xml" for engines shipped with Netfabb)
local machinetosearch="c238898e-35a3-4245-9184-92ec066ac7e5"
local found_tray = nil
local index

-- Iterate over all loaded trays and find the tray that 
-- belongs to the "Generic" engine
for index = 0, netfabbtrayhandler.traycount - 1 do
  local itertray = netfabbtrayhandler:gettray (index)
  if (itertray.workspacetype == machinetosearch) then
    found_tray = itertray
  end
end

-- If the Generic engine is not active an error is shown
if found_tray == nil then
  system:messagedlg("Engine not found.")
  return
end

-- The "callworkspace" method of the LUA tray calls the "executecustomevent(eventname, parameterstring)" function that
-- must be defined in the engine's LUA files. The parameters are passed to the executecustomevent function and can be
-- processed there to trigger any function that is needed. For demo purposes this callback is implemented in the "generic"
-- demo engine (main.lua) and accepts two commands: "alert" and "open". alert just opens a message dialog with the
-- second parameter as message whereas "open" allows to open the "Settings" dialog which must be specified by the second
-- parameter

-- Tray of the engine found, let's do something
found_tray:callworkspace("alert", "Hello Engine Messagebox")
-- Now let's open the "Settings" dialog
found_tray:callworkspace("open" , "Settings")
