-- LUA Script for Autodesk Netfabb 2021.0
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes only
--==============================================================================

-- This script shows how to control the clipping planes UI from LUA

GOutbox = tray.outbox

GDialog = application:createdialog()
GDialog.caption = "Clipping"
GDialog.translatecaption = false

GGroupbox = GDialog:addgroupbox()
GGroupbox.caption = "Clipping"
GGroupbox.translate = false

GAxis = GGroupbox:adddropdown()
GAxis.caption = "Axis"
GAxis.translate = false
GAxis.captionwidth = 100
GAxis:additem("X" , 0, 0, false)
GAxis:additem("Y" , 1, 1, false)
GAxis:additem("Z" , 2, 2, false)
GAxis.onchange = "scrollbar_change"

GHalfSpace = GGroupbox:adddropdown()
GHalfSpace.caption = "Halfspace"
GHalfSpace.translate = false
GHalfSpace.captionwidth = 100
GHalfSpace:additem("None"     , 0, 0, false)
GHalfSpace:additem("Both"     , 1, 1, false)
GHalfSpace:additem("Positive" , 2, 2, false)
GHalfSpace:additem("Negative" , 3, 3, false)
GHalfSpace.onchange = "scrollbar_change"

GContour = GGroupbox:addcheckbox()
GContour.caption = "Contour enabled"
GContour.translate = false

GSpace = GGroupbox:adddropdown()
GSpace.caption = "Space"
GSpace.translate = false
GSpace.captionwidth = 100
GSpace:additem("Model", 0, 0, false)
GSpace:additem("World", 1, 1, false)
GSpace:additem("View" , 2, 2, false)
GSpace.onchange = "scrollbar_change"

GDistance = GGroupbox:addscrollbar()
GDistance.max = math.max(GOutbox.maxx, GOutbox.maxy, GOutbox.maxz)
GDistance.height = 25
GDistance.onchange = "scrollbar_change"

GEdit = GGroupbox:addedit()
GEdit.caption = "Distance"
GEdit.translate = false
GEdit.captionwidth = 100
GEdit.text = "0"

GButton = GGroupbox:addbutton()
GButton.caption = "Screenshot"
GButton.translate = false
GButton.onclick = "screenshot_click"

function scrollbar_change()
  GEdit.text = tostring(GDistance.position)
  
  local AAxis      = GAxis.selecteditem
  local AHalfspace = hsNone
  
  if GHalfSpace.selecteditem == 1 then
    AHalfspace = hsBoth
  elseif GHalfSpace.selecteditem == 2 then
    AHalfspace = hsPositive
  elseif GHalfSpace.selecteditem == 3 then
    AHalfspace = hsNegative
  end
  
  local ASpace = csModel
  
  if GSpace.selecteditem == 1 then
    ASpace = csWorld
  elseif GSpace.selecteditem == 2 then
    ASpace = csView
  end
  
  ADistance = GDistance.position
  AContour  = GContour.checked
  
  tray:setclipplane(AAxis, AHalfspace, ASpace, ADistance, AContour)
end

function screenshot_click()
  local AFileName = system:showsavedialog("png")
  
  if AFileName ~= "" then
    local AOptions = system:createjson()
    AOptions:loadfromstring("{\"show_horizontalruler\":false,\"show_coordsystem\":false,\"show_verticalruler\":false}")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
  end
end

GDialog:show()