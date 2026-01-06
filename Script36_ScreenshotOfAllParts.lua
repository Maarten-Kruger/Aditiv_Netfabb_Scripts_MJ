-- LUA Script for Autodesk Netfabb 2021.0
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes only
--==============================================================================

-- This script shows a possibility to create screenshots from all meshes
GDialog = application:createdialog()
GDialog.caption = "Screenshots of all parts"
GDialog.translatecaption = false


GGroupbox = GDialog:addgroupbox()
GGroupbox.caption = "Screenshots of all parts"
GGroupbox.translate = false

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

function setVisibility(AVisible)
  local ARoot = tray.root
  for i = 0, ARoot.meshcount - 1 do
    local AMesh = ARoot:getmesh(i)
    AMesh.visible = AVisible
  end
end

function savescreenshots()
  setVisibility(false)
  
  local ARoot = tray.root
  for i = 0, ARoot.meshcount - 1 do
    
    local AMesh = ARoot:getmesh(i)
    AMesh.visible = true
    
    AMesh.selected = true
    system:zoomto(zoomtoSelected)
    AMesh.selected = false
    
    local AFileName = GEdit.text .. "/screenshot_mesh_" .. tostring(i) .. ".png"
    
    local AOptions = system:createjson()
    AOptions:loadfromstring("{\"show_horizontalruler\":false,\"show_coordsystem\":false,\"show_verticalruler\":false, \"show_labels\": false, \"show_viewcube\": false, \"show_coordsystem\": false, \"show_platform\": false, \"show_logo\": false, \"show_gizmo\": false }")
    local AImage = system:createscreenshot(1920, 1080, AOptions)
    AImage:saveto(AFileName)
    
    AMesh.visible = false
  end
  
  setVisibility(true)
  system:zoomto(zoomtoAllparts)
end

function closedialog()
  GDialog:close(false)
end

GDialog:show()