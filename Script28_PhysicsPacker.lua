-- LUA Script for Autodesk Netfabb 2021.1
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes only
--==============================================================================

-- This script shows how to access the physics packer from a LUA script

GPhysicsTimestep = {
  [0] = 0.005,
  [1] = 0.010,
  [2] = 0.015,
  [3] = 0.025,
  [4] = 0.040,
  [5] = 0.075,
  [6] = 0.100
}

GPhysicsVoxels = {
  [0] = 200000,
  [1] = 150000,
  [2] = 100000,
  [3] = 75000,
  [4] = 50000,
  [5] = 25000,
  [6] = 10000
}

GPhysicsDistance = {
  [0] = 0.0,
  [1] = 0.5,
  [2] = 1.0,
  [3] = 1.5,
  [4] = 2.0,
  [5] = 2.5,
  [6] = 3.0,
  [7] = 3.5,
  [8] = 4.0,
  [9] = 4.5,
  [10] = 5.0
}

dialog_arrangeparts = application:createdialog();
dialog_arrangeparts.caption = "Physics Packer";
dialog_arrangeparts.translatecaption = false

dialog_arrangeparts_timestep = dialog_arrangeparts:adddropdown()
dialog_arrangeparts_timestep.captionwidth = 150
dialog_arrangeparts_timestep.caption = "Timestep"
dialog_arrangeparts_timestep.translatecaption = false

for i = 0, table.getn(GPhysicsTimestep) do
  dialog_arrangeparts_timestep:additem(tostring(GPhysicsTimestep[i]), i, i, false)
end

dialog_arrangeparts_voxels = dialog_arrangeparts:adddropdown()
dialog_arrangeparts_voxels.captionwidth = 150
dialog_arrangeparts_voxels.caption = "Voxels"
dialog_arrangeparts_voxels.translatecaption = false

for i = 0, table.getn(GPhysicsVoxels) do
  dialog_arrangeparts_voxels:additem(tostring(GPhysicsVoxels[i]), i, i, false)
end

dialog_arrangeparts_partdistance = dialog_arrangeparts:adddropdown()
dialog_arrangeparts_partdistance.captionwidth = 150
dialog_arrangeparts_partdistance.caption = "FORM_DEFAULT_PHYSICSPACKING_PARTDISTANCE"

for i = 0, table.getn(GPhysicsDistance) do
  dialog_arrangeparts_partdistance:additem(string.format("%.1f", GPhysicsDistance[i]) .. " mm", i, i, false);
end

dialog_arrangeparts_itemrotation = dialog_arrangeparts:adddropdown()
dialog_arrangeparts_itemrotation.captionwidth = 150
dialog_arrangeparts_itemrotation.caption = "FORM_DEFAULT_PHYSICSPACKING_ROTATION"

dialog_arrangeparts_itemrotation:additem("FORM_DEFAULT_PHYSICSPACKING_ROTATION_ARBITRARY", 0, 0)
dialog_arrangeparts_itemrotation:additem("FORM_DEFAULT_PHYSICSPACKING_ROTATION_ZONLY"    , 1, 1)
dialog_arrangeparts_itemrotation:additem("FORM_DEFAULT_PHYSICSPACKING_ROTATION_NONE"     , 2, 2)

dialog_arrangeparts_walldistancexy = dialog_arrangeparts:adddropdown()
dialog_arrangeparts_walldistancexy.caption = "FORM_DEFAULT_PHYSICSPACKING_BORDERSPACINGXY"
dialog_arrangeparts_walldistancexy.captionwidth = 150

for i = 0, table.getn(GPhysicsDistance) do
  dialog_arrangeparts_walldistancexy:additem(string.format("%.1f", GPhysicsDistance[i]) .. " mm", i, i, false);
end
  
dialog_arrangeparts_walldistancez = dialog_arrangeparts:adddropdown()
dialog_arrangeparts_walldistancez.caption = "FORM_DEFAULT_PHYSICSPACKING_BORDERSPACINGZ"
dialog_arrangeparts_walldistancez.captionwidth = 150

for i = 0, table.getn(GPhysicsDistance) do
  dialog_arrangeparts_walldistancez:additem(string.format("%.1f", GPhysicsDistance[i]) .. " mm", i, i, false);
end

dialog_arrangeparts_onlyselected = dialog_arrangeparts:addcheckbox()
dialog_arrangeparts_onlyselected.caption = "FORM_DEFAULT_MODELINFO_SELECTEDPARTS"

function dialog_partarrange_onokclick()
  local ATimeStep     = GPhysicsTimestep[tonumber(dialog_arrangeparts_timestep.selecteditem)]
  local AVoxels       = GPhysicsVoxels  [tonumber(dialog_arrangeparts_voxels  .selecteditem)]
  
  local APartDistance  = GPhysicsDistance[dialog_arrangeparts_partdistance  .selecteditem]
  local ABorderSpaceXY = GPhysicsDistance[dialog_arrangeparts_walldistancexy.selecteditem]
  local ABorderSpaceZ  = GPhysicsDistance[dialog_arrangeparts_walldistancez .selecteditem]
  local AItemRotation  = dialog_arrangeparts_itemrotation  .selecteditem
  local APacker       = netfabbtrayhandler:gettray(0):createpacker(netfabbtrayhandler:gettray(0).packingid_physics)

  APacker.timestep        = ATimeStep
  APacker.minimaldistance = APartDistance
  APacker.itemrotation    = AItemRotation
  APacker.onlyselected    = dialog_arrangeparts_onlyselected.checked
  APacker.borderspacingxy = ABorderSpaceXY
  APacker.borderspacingz  = ABorderSpaceZ

  APacker:pack()

  APacker:release()
  
  dialog_arrangeparts:close (true)
end

function dialog_partarrange_oncancelclick()
  dialog_arrangeparts:close (false)
end;

splitter = dialog_arrangeparts:addsplitter()

splitter:settoleft()
button = splitter:addbutton()
button.caption = "GENERAL_OK"
button.onclick = "dialog_partarrange_onokclick"

splitter:settoright()
button = splitter:addbutton()
button.caption = "GENERAL_CANCEL"
button.onclick = "dialog_partarrange_oncancelclick"

dialog_arrangeparts:show()