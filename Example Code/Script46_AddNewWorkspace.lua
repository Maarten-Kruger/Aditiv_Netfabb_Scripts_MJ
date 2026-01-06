-- The the workspace ID for a machine called "Fuse 1" in the "My Machines" list
GWorkspaceID = netfabbtrayhandler:getmachineidentifier("Fuse 1")

-- If no such machine was found we can use the value of the "uuid" attribute of
-- the corresponding workspacedefinition in workspaces.xml
if GWorkspaceID == "" then
  GWorkspaceID = "691361E2-6F01-4F7E-BE38-529A531BB41D"
end

-- Create a new tray. If a machine from the "My Machines" list
-- was used it also contains the settings of this particular
-- machine, otherwise it comes with the default settings
GNewTray = netfabbtrayhandler:addworkspace(GWorkspaceID)