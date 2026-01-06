-- LUA Script for Autodesk Netfabb 2021.0
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes only
--==============================================================================

-- This script shows the camera control for screenshots

GDialog = application:createdialog()
GDialog.caption = "Screenshots of all parts"
GDialog.translatecaption = false


GGroupbox = GDialog:addgroupbox()
GGroupbox.caption = "Screenshots of all parts"
GGroupbox.translate = false

GCheckboxMoveX = GGroupbox:addcheckbox()
GCheckboxMoveX.translate = false
GCheckboxMoveX.caption = "Move Camera in X-Direction"
GCheckboxMoveX.checked = true

GCheckboxMoveY = GGroupbox:addcheckbox()
GCheckboxMoveY.translate = false
GCheckboxMoveY.caption = "Move Camera in Y-Direction"
GCheckboxMoveY.checked = true

GCheckboxRotate = GGroupbox:addcheckbox()
GCheckboxRotate.translate = false
GCheckboxRotate.caption = "Rotate Camera around Center"
GCheckboxRotate.checked = true

GCheckboxCenter = GGroupbox:addcheckbox()
GCheckboxCenter.translate = false
GCheckboxCenter.caption = "Move center point with fixed camera"
GCheckboxCenter.checked = true

GCheckboxUp = GGroupbox:addcheckbox()
GCheckboxUp.translate = false
GCheckboxUp.caption = "Rotate Up-Vector"
GCheckboxUp.checked = true

GCheckboxZoom = GGroupbox:addcheckbox()
GCheckboxZoom.translate = false
GCheckboxZoom.caption = "Zoom Camera"
GCheckboxZoom.checked = true

GCheckboxOutbox = GGroupbox:addcheckbox()
GCheckboxOutbox.translate = false
GCheckboxOutbox.caption = "Rotate with outbox center"
GCheckboxOutbox.checked = true

GEdit = GGroupbox:addedit()
GEdit.captionwidth = 120
GEdit.caption = "Output folder:"
GEdit.translate = false

GSplitter = GGroupbox:addsplitter()
GSplitter:settoleft()

GButton = GSplitter:addbutton()
GButton.caption = "Save Screenshots"
GButton.translate = false
GButton.onclick = "savescreenshots"

GSplitter:settoright()

GButton = GSplitter:addbutton()
GButton.caption = "Close"
GButton.translate = false
GButton.onclick = "closedialog"

function ScreenshotMoveX(AOutbox)
  local APosX  = AOutbox.minx
  local APosY  = AOutbox.miny - 25
  local APosZ  = (AOutbox.maxz - AOutbox.minz) / 2
  local AStepX = (AOutbox.maxx - AOutbox.minx) / 10
  
  -- In a first loop we place the camera in Y-direction off the buildroom and move the camera and the center point along the X-axis
  for i = 1, 10 do
    local AFileName = GEdit.text .. "/screenshot_movex_" .. tostring(i) .. ".png"
    local AOptions = system:createjson()
    AOptions:loadfromstring("{ \"camera\": { \"eye\": [ " .. tostring(APosX) .. ", " .. tostring(APosY) .. ", " .. tostring(APosZ) .. " ], \"center\": [" .. tostring(APosX) .. ", " .. tostring(APosY + 25) .. ", " .. tostring(APosZ) .. "], \"up\": [ 0.0, 0.0, 1.0 ] } }")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
    
    APosX = APosX + AStepX
  end
end

function ScreenshotMoveY(AOutbox)
  local APosX  = AOutbox.minx - 25
  local APosY  = AOutbox.miny
  local APosZ  = (AOutbox.maxz - AOutbox.minz) / 2
  local AStepY = (AOutbox.maxy - AOutbox.miny) / 10
  
  -- In the second loop we place the camera in X-direction off the buildroom and move the camera and the center point along the Y-axis
  for i = 1, 10 do
    local AFileName = GEdit.text .. "/screenshot_movey_" .. tostring(i) .. ".png"
    local AOptions = system:createjson()
    AOptions:loadfromstring("{ \"camera\": { \"eye\": [ " .. tostring(APosX) .. ", " .. tostring(APosY) .. ", " .. tostring(APosZ) .. " ], \"center\": [" .. tostring(APosX + 25) .. ", " .. tostring(APosY) .. ", " .. tostring(APosZ) .. "], \"up\": [ 0.0, 0.0, 1.0 ] } }")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
    
    APosY = APosY + AStepY
  end
end

function ScreenshotRotate(AOutbox)
  local APosX    = AOutbox.minx - 25
  local APosY    = AOutbox.miny
  local APosZ    = (AOutbox.maxz - AOutbox.minz) / 2
  local ACenterX = (AOutbox.maxx - AOutbox.minx) / 2
  local ACenterY = (AOutbox.maxy - AOutbox.miny) / 2
  
  APosZ = (AOutbox.maxz - AOutbox.minz) / 10
  
  -- The third loop shows a rotation around the center of the build platform in 10 steps
  for i = 1, 10 do
    APosX = 25 * math.cos((36 * i) * math.pi / 180.0) + ACenterX
    APosY = 25 * math.sin((36 * i) * math.pi / 180.0) + ACenterY
    
    local AFileName = GEdit.text .. "/screenshot_rotate_" .. tostring(i) .. ".png"
    local AOptions = system:createjson()
    AOptions:loadfromstring("{ \"camera\": { \"eye\": [ " .. tostring(APosX) .. ", " .. tostring(APosY) .. ", " .. tostring(APosZ) .. " ], \"center\": [ " .. tostring(ACenterX) .. ", " .. tostring(ACenterY) .. ", 0.0 ], \"up\": [ 0.0, 0.0, 1.0 ] } }")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
  end
end

function ScreenshotCenter(AOutbox)
  local APosX    = AOutbox.maxx + 10
  local APosY    = (AOutbox.maxy - AOutbox.miny) / 2
  local APosZ    = (AOutbox.maxz - AOutbox.minz) / 2
  local ACenterX = (AOutbox.maxx - AOutbox.minx) / 2
  local ACenterY = AOutbox.miny
  local AStepY   = (AOutbox.maxy - AOutbox.miny) / 10
  
  
  -- This time we keep the camera fixed and move the center point along a line
  for i = 1, 10 do
    local AFileName = GEdit.text .. "/screenshot_movecenter_" .. tostring(i) .. ".png"
    local AOptions = system:createjson()
    AOptions:loadfromstring("{ \"camera\": { \"eye\": [ " .. tostring(APosX) .. ", " .. tostring(APosY) .. ", " .. tostring(APosZ) .. " ], \"center\": [ " .. tostring(ACenterX) .. ", " .. tostring(ACenterY) .. ", 0.0 ], \"up\": [ 0.0, 0.0, 1.0 ] } }")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    ACenterY = ACenterY + AStepY
    AImage:saveto(AFileName)
  end
end

function ScreenshotUp(AOutbox)
  local APosX    = AOutbox.minx - 25
  local APosY    = (AOutbox.maxy - AOutbox.miny) / 2
  local APosZ    = (AOutbox.maxz - AOutbox.minz) / 2
  local ACenterX = (AOutbox.maxx - AOutbox.minx) / 2
  local ACenterY = (AOutbox.maxy - AOutbox.miny) / 2
  
  -- This time it doesn't make any sense at all, but for demo purposes we just rotate the up vector by 180 degrees in 10 steps
  for i = 1, 10 do
    local AUpY = math.cos(18 * i * math.pi / 180)
    local AUpZ = math.sin(18 * i * math.pi / 180)
    
    local AFileName = GEdit.text .. "/screenshot_up_" .. tostring(i) .. ".png"
    local AOptions = system:createjson()
    AOptions:loadfromstring("{ \"camera\": { \"eye\": [ " .. tostring(APosX) .. ", " .. tostring(APosY) .. ", " .. tostring(APosZ) .. " ], \"center\": [ " .. tostring(ACenterX) .. ", " .. tostring(ACenterY) .. ", 0.0 ], \"up\": [ 0.0, " .. tostring(AUpY) .. ", " .. tostring(AUpZ) .. " ] } }")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
  end
end

function ScreenshotZoom(AOutbox)
  local ACenterX = (AOutbox.maxx - AOutbox.minx) / 2
  local ACenterY = (AOutbox.maxy - AOutbox.miny) / 2
  local APosX    = ACenterX - 25
  local APosY    = ACenterY
  local APosZ    = (AOutbox.maxz - AOutbox.minz) / 2
  
  local AZoom = 0.5
  -- Last but not least we iterate the zoom factor from 0.5 to 5 in 10 steps
  for i = 1, 10 do
    local AFileName = GEdit.text .. "/screenshot_zoom_" .. tostring(i) .. ".png"
    local AOptions = system:createjson()
    AOptions:loadfromstring("{ \"camera\": { \"eye\": [ " .. tostring(APosX) .. ", " .. tostring(APosY) .. ", " .. tostring(APosZ) .. " ], \"center\": [ " .. tostring(ACenterX) .. ", " .. tostring(ACenterY) .. ", 0.0 ], \"up\": [ 0.0, 0.0, 1.0 ], \"zoom\": " .. tostring(AZoom) .. " } }")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
    
    AZoom = AZoom + 0.5
  end
end

function ScreenshotOutbox(AOutbox)
  local ACenterX = (AOutbox.maxx - AOutbox.minx) / 2
  local ACenterY = (AOutbox.maxy - AOutbox.miny) / 2
  local APosZ    = (AOutbox.maxz - AOutbox.minz) / 10
  
  local AOutboxString = tostring(AOutbox.minx) .. ", " .. tostring(AOutbox.miny) .. ", " .. tostring(AOutbox.minz) .. ", " .. tostring(AOutbox.maxx) .. ", " .. tostring(AOutbox.maxy) .. ", " .. tostring(AOutbox.maxz)
  
  -- The third loop shows a rotation around the center of the build platform in 10 steps
  for i = 1, 10 do
    -- if you're using the outbox the position of the camera is relative to the outbox center
    local APosX = 25 * math.cos((36 * i) * math.pi / 180.0)
    local APosY = 25 * math.sin((36 * i) * math.pi / 180.0)
    
    local AFileName = GEdit.text .. "/screenshot_outbox_" .. tostring(i) .. ".png"
    local AOptions = system:createjson()
    AOptions:loadfromstring("{ \"camera\": { \"eye\": [ " .. tostring(APosX) .. ", " .. tostring(APosY) .. ", " .. tostring(APosZ) .. " ], \"up\": [ 0.0, 0.0, 1.0 ], \"outbox\": [ " .. AOutboxString .. " ] } }")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
  end
end

function savescreenshots()
  local AOutbox = tray.outbox
  
  if GCheckboxMoveX .checked then ScreenshotMoveX (AOutbox) end
  if GCheckboxMoveY .checked then ScreenshotMoveY (AOutbox) end
  if GCheckboxRotate.checked then ScreenshotRotate(AOutbox) end
  if GCheckboxCenter.checked then ScreenshotCenter(AOutbox) end
  if GCheckboxUp    .checked then ScreenshotUp    (AOutbox) end
  if GCheckboxZoom  .checked then ScreenshotZoom  (AOutbox) end
  if GCheckboxOutbox.checked then ScreenshotOutbox(AOutbox) end
end

function closedialog()
  GDialog:close(false)
end

GDialog:show()