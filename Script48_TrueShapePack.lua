-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Packs the current tray  

function RotationTypeChange()
  local AItem = ARotationType.selecteditem
  
  ARotationStepX    .enabled = AItem == 0
  ARotationStepY    .enabled = AItem == 0
  ARotationStepZ    .enabled = AItem == 0
  ARotationMultiAxis.enabled = AItem == 0
  ARotationList     .enabled = AItem == 1
end

function ComponentPlacementChanged()
  AInterlockCheck.enabled = AAdvancedSettings.checked
  ACompPlacement .enabled = AAdvancedSettings.checked
  APriorities    .enabled = AAdvancedSettings.checked
  
  AAxis.enabled       = AAdvancedSettings.checked and ACompPlacement.selecteditem == 0
  ASweetSpotX.enabled = AAdvancedSettings.checked and ACompPlacement.selecteditem == 1
  ASweetSpotY.enabled = AAdvancedSettings.checked and ACompPlacement.selecteditem == 1
end

function CloneParent(AParent, ATarget, ACount)
  local ASourceMeshes = { }
  
  for AIndex = 0, AParent.meshcount - 1 do
    table.insert(ASourceMeshes, AParent:getmesh(AIndex))
  end
  
  for k,v in pairs(ASourceMeshes) do
    for AClone = 1, ACount do
      if not v.lockedposition then
        local AMesh = ATarget:addmesh(v.mesh)
        AMesh.name = v.name .. "_" .. tostring(AClone)
        AMesh:setmatrix(v.matrix)
      end
    end
  end
  
  for AIndex = 0, AParent.groupcount - 1 do
    for AClone = 1, ACount do
      local AGroup    = AParent:getsubgroup(AIndex)
      local ANewGroup = ATarget:addsubgroup(AGroup.name .. "_" .. tostring(AClone))

      ANewGroup.locked = AGroup.locked
      
      CloneParent(AGroup, ANewGroup, 1)
    end
  end
end

-- Move the parts of the group outside the platform,
-- otherwise parts which cannot be packed are not moved at all
function MovePartsOutsidePlatform(AGroup)
  for AIndex = 0, AGroup.meshcount - 1 do
    local AMesh = AGroup:getmesh(AIndex)
    
    if not AMesh.lockedposition then
      local AOutbox = AMesh.outbox
      
      AMesh:translate(-(AOutbox.maxx + AOutbox.sizex), -(AOutbox.maxy + AOutbox.sizey), 0)
    end
  end
  
  for AIndex = 0, AGroup.groupcount - 1 do
    local ASubGroup = AGroup:getsubgroup(AIndex)
    local AOutbox   = AGroup.outbox
    
    ASubGroup:translate(-(AOutbox.maxx + AOutbox.sizex), -(AOutbox.maxy + AOutbox.sizey), 0)
    
    system:messagedlg("Move Group: " .. tostring(-(AOutbox.maxx + AOutbox.sizex)) .. ", " .. tostring(-(AOutbox.maxy + AOutbox.sizey)))
  end
end

function Change2dPacking()
  AUseShadow.enabled = A2dPacking.checked
  
  AAxis:clear()
  AAxis:additem("Positive X Axis", 0, 0, false)
  AAxis:additem("Positive Y Axis", 1, 1, false)
  
  if not A2dPacking.checked then
    AAxis:additem("Positive Z Axis", 2, 2, false)
  end

  AAxis:additem("Negative X Axis", 3, 3, false)
  AAxis:additem("Negative Y Axis", 4, 4, false)
  
  if not A2dPacking.checked then
    AAxis:additem("Negative Z Axis", 5, 5, false)
  end
  
  AAxis:updateitems()
end

function BtnPack()
  ADialog:close(true)
end

function BtnClose()
  ADialog:close(false)
end

system:setloggingtooglwindow(true)

ACaptionWidth = 180

ADialog = application:createdialog()


ADialog.caption = "LUA automation demo for the True Shape Packer"
ADialog.translatecaption = false
ADialog.width = 360

AGroup = ADialog:addgroupbox()

AGroup.caption   = "Settings"
AGroup.translate = false

A2dPacking = AGroup:addcheckbox()
A2dPacking.caption   = "2d packing"
A2dPacking.translate = false
A2dPacking.onclick   = "Change2dPacking"

AUseShadow = AGroup:addcheckbox()
AUseShadow.caption   = "Avoid packing parts in the shadow of other parts"
AUseShadow.translate = false
AUseShadow.enabled   = false

APackingOrder = AGroup:adddropdown()

APackingOrder.caption          = "Packing Order"
APackingOrder.captionwidth     = ACaptionWidth
APackingOrder.translatecaption = false
APackingOrder.translate        = false

APackingOrder:additem("Part Volume or Priority", 0, 0, false)
APackingOrder:additem("Project Tree"           , 1, 1, false)

AVoxelSize = AGroup:addedit()
AVoxelSize.caption      = "Voxel Size"
AVoxelSize.translate    = false
AVoxelSize.captionwidth = ACaptionWidth
AVoxelSize.text         = "4.0"
AVoxelSize.numbersonly  = true

APartCopies = AGroup:addedit()
APartCopies.caption      = "Global Part Duplicates"
APartCopies.translate    = false
APartCopies.captionwidth = ACaptionWidth
APartCopies.text         = "1"
APartCopies.numbersonly  = true

APartDistance = AGroup:addedit()
APartDistance.caption      = "Minimum Part Distance (mm)"
APartDistance.translate    = false
APartDistance.captionwidth = ACaptionWidth
APartDistance.text         = "2.0"
APartDistance.numbersonly  = true

ADistanceXY = AGroup:addedit()
ADistanceXY.caption      = "Distance to side walls (XY, mm)"
ADistanceXY.translate    = false
ADistanceXY.captionwidth = ACaptionWidth
ADistanceXY.text         = "2.0"
ADistanceXY.numbersonly  = true

ADistancePlatform = AGroup:addedit()
ADistancePlatform.caption      = "Distance to platform (mm)"
ADistancePlatform.translate    = false
ADistancePlatform.captionwidth = ACaptionWidth
ADistancePlatform.text         = "2.0"
ADistancePlatform.numbersonly  = true

ADistanceCeiling = AGroup:addedit()
ADistanceCeiling.caption      = "Distance to ceiling (mm)"
ADistanceCeiling.translate    = false
ADistanceCeiling.captionwidth = ACaptionWidth
ADistanceCeiling.text         = "2.0"
ADistanceCeiling.numbersonly  = true

ARotationType = AGroup:adddropdown()
ARotationType.caption          = "Rotation Type"
ARotationType.captionwidth     = ACaptionWidth
ARotationType.translatecaption = false
ARotationType.translate        = false
ARotationType.onchange         = "RotationTypeChange"


ARotationType:additem("Rotation Steppings", 0, 0, false)
ARotationType:additem("Rotation List"     , 1, 1, false)

ARotationStepX = AGroup:adddropdown()
ARotationStepX.caption          = "X Rotation"
ARotationStepX.captionwidth     = ACaptionWidth
ARotationStepX.translatecaption = false
ARotationStepX.translate        = false

ARotationStepX:additem(  "0.0", 0, 0, false)
ARotationStepX:additem("180.0", 1, 1, false)
ARotationStepX:additem( "90.0", 2, 2, false)
ARotationStepX:additem( "60.0", 3, 3, false)
ARotationStepX:additem( "45.0", 4, 4, false)
ARotationStepX:additem( "36.0", 5, 5, false)
ARotationStepX:additem( "30.0", 6, 6, false)
ARotationStepX:additem( "20.0", 7, 7, false)

ARotationStepY = AGroup:adddropdown()
ARotationStepY.caption          = "Y Rotation"
ARotationStepY.captionwidth     = ACaptionWidth
ARotationStepY.translatecaption = false
ARotationStepY.translate        = false

ARotationStepY:additem(  "0.0", 0, 0, false)
ARotationStepY:additem("180.0", 1, 1, false)
ARotationStepY:additem( "90.0", 2, 2, false)
ARotationStepY:additem( "60.0", 3, 3, false)
ARotationStepY:additem( "45.0", 4, 4, false)
ARotationStepY:additem( "36.0", 5, 5, false)
ARotationStepY:additem( "30.0", 6, 6, false)
ARotationStepY:additem( "20.0", 7, 7, false)

ARotationStepZ = AGroup:adddropdown()
ARotationStepZ.caption          = "Z Rotation"
ARotationStepZ.captionwidth     = ACaptionWidth
ARotationStepZ.translatecaption = false
ARotationStepZ.translate        = false

ARotationStepZ:additem(  "0.0", 0, 0, false)
ARotationStepZ:additem("180.0", 1, 1, false)
ARotationStepZ:additem( "90.0", 2, 2, false)
ARotationStepZ:additem( "60.0", 3, 3, false)
ARotationStepZ:additem( "45.0", 4, 4, false)
ARotationStepZ:additem( "36.0", 5, 5, false)
ARotationStepZ:additem( "30.0", 6, 6, false)
ARotationStepZ:additem( "20.0", 7, 7, false)

ARotationStepZ.selecteditem = 2

ARotationMultiAxis = AGroup:addcheckbox()
ARotationMultiAxis.caption   = "Include mulit-axis variants"
ARotationMultiAxis.translate = false

ARotationList = AGroup:addedit()
ARotationList.caption      = "Rotation list (X;Y;Z)"
ARotationList.translate    = false
ARotationList.captionwidth = ACaptionWidth
ARotationList.text         = "(0;0;0)(0;0;90)(0;0;180)(0;0;270)"
ARotationList.enabled      = false

AAdvancedSettings = AGroup:addcheckbox()
AAdvancedSettings.caption   = "Advanced Packer Settings"
AAdvancedSettings.translate = false
AAdvancedSettings.checked   = false
AAdvancedSettings.onclick   = "ComponentPlacementChanged"

AInterlockCheck = AGroup:addcheckbox()
AInterlockCheck.caption      = "Interlock Check"
AInterlockCheck.translate    = false
AInterlockCheck.checked      = true

ACompPlacement = AGroup:adddropdown()
ACompPlacement.caption          = "Part Placement"
ACompPlacement.captionwidth     = ACaptionWidth
ACompPlacement.translatecaption = false
ACompPlacement.translate        = false
ACompPlacement.onchange         = "ComponentPlacementChanged"

ACompPlacement:additem("Along Axis" , 0, 0, false)
ACompPlacement:additem("Sweet Spot" , 1, 1, false)
ACompPlacement:additem("Center Bias", 2, 2, false)

AAxis = AGroup:adddropdown()
AAxis.caption          = "Direction"
AAxis.captionwidth     = ACaptionWidth
AAxis.translatecaption = false
AAxis.translate        = false

AAxis:additem("Positive X Axis", 0, 0, false)
AAxis:additem("Positive Y Axis", 1, 1, false)
AAxis:additem("Positive Z Axis", 2, 2, false)

AAxis:additem("Negative X Axis", 3, 3, false)
AAxis:additem("Negative Y Axis", 4, 4, false)
AAxis:additem("Negative Z Axis", 5, 5, false)

ASweetSpotX = AGroup:addedit()
ASweetSpotX.caption      = "Sweet spot X position"
ASweetSpotX.translate    = false
ASweetSpotX.captionwidth = ACaptionWidth
ASweetSpotX.text         = "0.0"
ASweetSpotX.numbersonly  = true

ASweetSpotY = AGroup:addedit()
ASweetSpotY.caption      = "Sweet spot Y position"
ASweetSpotY.translate    = false
ASweetSpotY.captionwidth = ACaptionWidth
ASweetSpotY.text         = "0.0"
ASweetSpotY.numbersonly  = true

APriorities = AGroup:adddropdown()
APriorities.caption          = "Placement Priorities"
APriorities.captionwidth     = ACaptionWidth
APriorities.translatecaption = false
APriorities.translate        = false

APriorities:additem("Example 1"  , 0, 0, false)
APriorities:additem("Example 2"  , 1, 1, false)
APriorities:additem("Example 3"  , 2, 2, false)
APriorities:additem("Example 4"  , 3, 3, false)
APriorities:additem("All Options", 4, 4, false)

ASplitter = ADialog:addsplitter()
ASplitter:settoleft()

AButtonPack = ASplitter:addbutton()
AButtonPack.caption   = "Pack"
AButtonPack.translate = false
AButtonPack.onclick   = "BtnPack"

ASplitter:settoright()

AButtonClose = ASplitter:addbutton()
AButtonClose.caption   = "Close"
AButtonClose.translate = false
AButtonClose.onclick   = "BtnClose"

ComponentPlacementChanged()

if ADialog:show() == true then
  local ACopies = tonumber(APartCopies.text)
  
  if ACopies > 1 then
    CloneParent(tray.root, tray.root, ACopies - 1)
  end
  
  local ADone = false
  local ATray = tray
  
  repeat
    MovePartsOutsidePlatform(ATray.root)
    
    -- Please note that the createpacker command creates a snapeshoot of the
    -- tray with it's current parts. If parts are removed or added afterwards 
    -- you need to create a new packer
    local packer = ATray:createpacker(ATray.packingid_trueshape)
    
    packer.showprogress          = true
    packer.packing_2d            = A2dPacking        .checked
    packer.packing_use_shadow_2d = AUseShadow        .checked
    packer.rotation_use_compound = ARotationMultiAxis.checked
    packer.rotation_use_list     = ARotationType.selecteditem == 1
    packer.borderspacingxy       = tonumber(ADistanceXY      .text)
    packer.borderspacingz        = tonumber(ADistancePlatform.text)
    packer.minimaldistance       = tonumber(APartDistance    .text)
    packer.voxel_size            = tonumber(AVoxelSize       .text)
    packer.rotation_x            = tonumber(ARotationStepX:getitemtext(ARotationStepX.selecteditem))
    packer.rotation_y            = tonumber(ARotationStepY:getitemtext(ARotationStepY.selecteditem))
    packer.rotation_z            = tonumber(ARotationStepZ:getitemtext(ARotationStepZ.selecteditem))
    packer.rotation_list         = ARotationList.text
    
    -- If wanted we apply the advanced settings
    if AAdvancedSettings.checked == true then
      packer.avoid_interlocking = AInterlockCheck.checked
      
      local APlacement = ACompPlacement.selecteditem
      
      if APlacement == 0 then
        packer.part_placement = packer.place_alongaxis
        
        if A2dPacking.checked then
          -- For the 2d packer only two values are passed to "setdirectionaxis"
          --using the packer constants "axis_[positive|negative]_[x|y|z]
          if AAxis.selecteditem == 0 then
            packer:setdirectionaxis(packer.axis_positive_x, packer.axis_positive_y)
          elseif AAxis.selecteditem == 1 then
            packer:setdirectionaxis(packer.axis_positive_y, packer.axis_positive_x)
          elseif AAxis.selecteditem == 3 then
            packer:setdirectionaxis(packer.axis_negative_x, packer.axis_negative_y)
          elseif AAxis.selecteditem == 4 then
            packer:setdirectionaxis(packer.axis_negative_y, packer.axis_negative_x)
          end
        else
          -- Setting the axes for 3d packing needs three values passed
          -- to the "setdirectionaxis" method, using the packer constants
          -- "axis_[positive|negative]_[x|y|z]
          if AAxis.selecteditem == 0 then
            packer:setdirectionaxis(packer.axis_positive_x, packer.axis_positive_y, packer.axis_positive_z)
          elseif AAxis.selecteditem == 1 then
            packer:setdirectionaxis(packer.axis_positive_y, packer.axis_positive_x, packer.axis_positive_z)
          elseif AAxis.selecteditem == 2 then
            packer:setdirectionaxis(packer.axis_positive_z, packer.axis_positive_x, packer.axis_positive_y)
          elseif AAxis.selecteditem == 3 then
            packer:setdirectionaxis(packer.axis_negative_x, packer.axis_negative_y, packer.axis_positive_z)
          elseif AAxis.selecteditem == 4 then
            packer:setdirectionaxis(packer.axis_negative_y, packer.axis_negative_x, packer.axis_positive_z)
          elseif AAxis.selecteditem == 5 then
            packer:setdirectionaxis(packer.axis_negative_z, packer.axis_negative_x, packer.axis_negative_y)
          end
        end
      elseif APlacement == 1 then
        packer.part_placement = packer.place_sweetspot
        packer.sweetspot_x    = tonumber(ASweetSpotX.text)
        packer.sweetspot_y    = tonumber(ASweetSpotY.text)
      elseif APlacement == 2 then
        -- The "Center Bias" option puts the sweet spot
        -- to the center of the platform
        packer.part_placement = packer.place_sweetspot
        packer.sweetspot_x    = ATray.machinesize_x / 2.0
        packer.sweetspot_y    = ATray.machinesize_x / 2.0
      end
      
      -- Here we pass some example values for the priority ranking.
      -- The meshes are sorted using the first criterium, if not
      -- distinction was detected the second is used and so on.
      -- All possible options are used in the four examples. Here
      -- we only pass 3 options but all 6 can be used as well.
      -- Example 5 shows that
      if APriorities.selecteditem == 0 then
        packer:setplacementpriorities(packer.minimum_buildbox_volume, packer.minimum_build_height, packer.maximum_contact_area)
      elseif APriorities.selecteditem == 1 then
        packer:setplacementpriorities(packer.minimum_build_height, packer.maximum_contact_area, packer.maximum_box_overlap)
      elseif APriorities.selecteditem == 2 then
        packer:setplacementpriorities(packer.maximum_contact_area, packer.maximum_box_overlap, packer.minimum_part_box_volume)
      elseif APriorities.selecteditem == 3 then
        packer:setplacementpriorities(packer.maximum_box_overlap, packer.minimum_part_box_volume, packer.minimum_part_height)
      elseif APriorities.selecteditem == 4 then
        packer:setplacementpriorities(
          packer.minimum_buildbox_volume, 
          packer.minimum_build_height, 
          packer.maximum_contact_area,
          packer.maximum_box_overlap,
          packer.minimum_part_box_volume,
          packer.minimum_part_height
        )
      end
    end
       
    -- set some of the additional parameters if the null packer is used
    local errorcode = packer:pack()
    
    local AUnPackedList  = { }
    local AUnPackedCount = 0
    local APackedCount   = 0
    
    
    for AIndex = 0, ATray.root.meshcount - 1 do
      local AMesh = ATray.root:getmesh(AIndex)
      if AMesh.packingstate == packer.isLeftover then
        AUnPackedCount = AUnPackedCount + 1
        table.insert(AUnPackedList, AMesh)
      elseif tray.root:getmesh(AIndex).packingstate == packer.isPacked then
        APackedCount = APackedCount + 1
      end
    end
    
    if AUnPackedCount == 0 then
      system:messagedlg("All parts were packed, packing finished.")
      ADone = true
    else
      local AInput = system:yesnodlg(tostring(AUnPackedCount) .. " parts were not packed. Do you want to continue on a new platform?")
      if AInput == 0 then
        ADone = true
      else
        local ANewTray = netfabbtrayhandler:addtray("NewPlatform_" .. tostring(netfabbtrayhandler.traycount), ATray.machinesize_x, ATray.machinesize_y, ATray.machinesize_z)
        
        for k,v in pairs(AUnPackedList) do
          ANewTray.root:addmesh(v.mesh)
          ATray.root:removemesh(v)
        end
        
        ATray = ANewTray
      end
    end
    
  until ADone == true
end