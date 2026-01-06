-- LUA Script for Autodesk Netfabb 2021.0
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes only
--==============================================================================

-- This script shows how to control the camera of Netfabb from LUA to automatically
-- create screenshots from a defined perspective
GDialog = application:createdialog()
GDialog.caption = "Set Camera"
GDialog.translatecaption = false

GGroupbox = GDialog:addgroupbox()
GGroupbox.caption = "Orientation"
GGroupbox.translate = false

GOrientation = GGroupbox:adddropdown()
GOrientation:additem("Front" , 1, 1, false)
GOrientation:additem("Back"  , 2, 2, false)
GOrientation:additem("Left"  , 3, 3, false)
GOrientation:additem("Right" , 4, 4, false)
GOrientation:additem("Top"   , 5, 5, false)
GOrientation:additem("Bottom", 6, 6, false)
GOrientation:additem("Iso"   , 7, 7, false)

GButtonOrient = GGroupbox:addbutton()
GButtonOrient.caption = "Change Orientation"
GButtonOrient.translate = false
GButtonOrient.onclick = "change_orientation"

GGroupbox = GDialog:addgroupbox()
GGroupbox.caption = "Zoom To"
GGroupbox.translate = false

GZoomTo = GGroupbox:adddropdown()
GZoomTo.caption = "Zoom To"
GZoomTo:additem("Everything", 1, 1, false)
GZoomTo:additem("Platform"  , 2, 2, false)
GZoomTo:additem("All Parts" , 3, 3, false)
GZoomTo:additem("Selected"  , 4, 4, false)
GZoomTo:additem("Home"      , 5, 5, false)

GButtonZoom = GGroupbox:addbutton()
GButtonZoom.caption = "Zoom To"
GButtonZoom.translate = false
GButtonZoom.onclick = "zoom_to"

GButtonScreenshot = GGroupbox:addbutton()
GButtonScreenshot.caption = "Screenshot"
GButtonScreenshot.translate = false
GButtonScreenshot.onclick = "save_screenshot"

function change_orientation()
  if GOrientation.selecteditem == 1 then
    system:setcameraorientation(cameraFront)
  elseif GOrientation.selecteditem == 2 then
    system:setcameraorientation(cameraBack)
  elseif GOrientation.selecteditem == 3 then
    system:setcameraorientation(cameraLeft)
  elseif GOrientation.selecteditem == 4 then
    system:setcameraorientation(cameraRight)
  elseif GOrientation.selecteditem == 5 then
    system:setcameraorientation(cameraTop)
  elseif GOrientation.selecteditem == 6 then
    system:setcameraorientation(cameraBottom)
  elseif GOrientation.selecteditem == 7 then
    system:setcameraorientation(cameraIso)
  end
end

function zoom_to()
  if GZoomTo.selecteditem == 1 then
    system:zoomto(zoomtoEverything)
  elseif GZoomTo.selecteditem == 2 then
    system:zoomto(zoomtoPlatform)
  elseif GZoomTo.selecteditem == 3 then
    system:zoomto(zoomtoAllparts)
  elseif GZoomTo.selecteditem == 4 then
    system:zoomto(zoomtoSelected)
  elseif GZoomTo.selecteditem == 5 then
    system:zoomto(zoomtoHome)
  end
end

function save_screenshot()
  local AFileName = system:showsavedialog("png")
  
  if AFileName ~= "" then
    change_orientation()
    zoom_to()
    
    local AOptions = system:createjson()
    AOptions:loadfromstring("{\"show_horizontalruler\":false,\"show_coordsystem\":false,\"show_verticalruler\":false}")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
  end
end

GDialog:show()