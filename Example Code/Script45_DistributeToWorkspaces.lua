-- LUA Script for Autodesk Netfabb 2024.0
-- Copyright by Autodesk 2023
-- This script is for demonstration purposes
--==============================================================================

GAddedTrays = { } -- A list of the added trays

-- This function fill a list of the meshes which need to be moved.
-- If this is for the first new workspace all meshes are added to
-- the list, otherwise only meshes which are not inside the build
-- room will be added and later moved to the next new workspace
function fillMeshList(AGroup, ATray)
  local AMeshes = { }

  for AIndex = 0, AGroup.meshcount - 1 do
    local AMesh = AGroup:getmesh(AIndex)
    if table.getn(GAddedTrays) == 0 or not ATray:ismeshinsidetray(AMesh) then
      table.insert(AMeshes, AMesh)
    end
  end

  return AMeshes
end

GCurrentTray = tray

-- We want to add all meshes to the "Formlabs Fuse 1" workspace.
-- In this call we search for the identifier of a workspace instance
-- (my machines) with the name "Fuse 1". If no such instance is found
-- we distribute the parts in "Formlabs Form 2" workspaces. 

-- The main difference here is that a "Fuse 1" workspace is already
-- in the "My Machines" list and can therefore have specific settings,
-- whereas the "Form 2" workspaces are new workspaces which do come
-- with the default settings. This UUID is taken from the "uuid" tag
-- in the "workspacedefinition" node of the workspaces.xml file
-- located in the Netfabb installation folder
GWorkspaceID = netfabbtrayhandler:getmachineidentifier("Fuse 1")

if GWorkspaceID == "" then
  system:messagedlg("Workspace instance not found, using Formlabs Form 2 instead.")
  GWorkspaceID = "7D5A65DA-A03B-4106-9A82-C78ADB19E986"
end

if GCurrentTray ~= nil then
  repeat
    -- Fill the list with the meshes to move
    local AMeshesToMove = fillMeshList(GCurrentTray.root, GCurrentTray)
    
    -- We stop processing if no meshes to move were found ...
    if table.getn(AMeshesToMove) == 0 then
      system:messagedlg(tostring(table.getn(GAddedTrays)) .. " trays added.")
      return
    -- ... or ten new workspaces have already been created
    elseif table.getn(GAddedTrays) >= 10 then
      system:messagedlg("Maximum of 10 trays added.")
      return
    end
    
    -- Add a new tray using the workspace ID
    local ANewTray = netfabbtrayhandler:addworkspace(GWorkspaceID)
    
    if ANewTray == nil then
      -- If for some reason adding the new tray did not work (e.g. invalid ID)
      -- we exit the script with a message
      system:messagedlg("ANewTray == nil!")
      return
    end
    
    local AMeshes = { }
    
    -- we iterate over all the meshes which are marked as to move
    -- and add them to the tray of the new workspace
    for k,v in pairs(AMeshesToMove) do
      local ANewMesh = ANewTray.root:addmesh(v.mesh, v.name)
      if ANewMesh ~= nil then
        table.insert(AMeshes, ANewMesh)
      end
    end
    
    -- As we want to move, not copy, the meshes we removemesh
    -- all meshes in the list from the workspace created before.
    -- The meshes remain in the original build room however.
    if table.getn(GAddedTrays) > 0 then
      for k,v in pairs(AMeshesToMove) do
        GCurrentTray.root:removemesh(v)
      end
    end
    
    -- Now we use the outbox packer to distribute the new meshes
    -- inside the build room
    local APacker = ANewTray:createpacker(ANewTray.packingid_outbox)
    APacker:pack()
    
    -- Add the new tray to the list of created trays
    table.insert(GAddedTrays, ANewTray)
    
    -- Store the newly created tray to remove
    -- meshes which are moved to the next tray
    GCurrentTray = ANewTray  
  until table.getn(AMeshesToMove) == 0
else
  system:messagedlg("tray == nil!")
end