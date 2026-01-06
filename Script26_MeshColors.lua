-- LUA Script for Autodesk Netfabb 2019.1
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script shows a dialog and lets you modify mesh colors
GDialog = application:createdialog()
GDialog.caption = "Modify Mesh Color"
GDialog.translatecaption = false

GMesh = GDialog:adddropdown()
GMesh.caption = "Mesh to color"
GMesh.captionwidth = 120
GMesh.translate = false

GTray = netfabbtrayhandler:gettray(0)

for i = 0, GTray.root.meshcount - 1 do
  local AMesh = GTray.root:getmesh(i)
  GMesh:additem(AMesh.name, i, i, false)
end

GMesh.onchange = "mesh_selected"

GColor = GDialog:adddropdown()
GColor.caption = "New Color"
GColor.captionwidth = 120
GColor.translate = false

GColor:additem("$FF0000", 0, 0, false)
GColor:additem("$00FF00", 1, 1, false)
GColor:additem("$0000FF", 2, 2, false)
GColor:additem("$FFFF00", 3, 3, false)
GColor:additem("$FF00FF", 4, 4, false)
GColor:additem("$00FFFF", 5, 5, false)
GColor:additem("$FFFFFF", 6, 6, false)
GColor:additem("$000000", 7, 7, false)

GButtonColor = GDialog:addbutton()
GButtonColor.caption = "Apply Color"
GButtonColor.translate = false
GButtonColor.onclick = "apply_color"

GShowColorTexture = GDialog:addcheckbox()
GShowColorTexture.caption = "Show Color and Texture"
GShowColorTexture.translate = false
GShowColorTexture.onclick = "showcolortexture"
GShowColorTexture.checked = application.showcolortexture

function close_form()
  GDialog:close(true)
end

function showcolortexture()
  application.showcolortexture = GShowColorTexture.checked
end

function mesh_selected()
  local ASelected = GMesh.selectedindex
  local AName = GMesh:getitemtext(ASelected)

  for i = 0, GTray.root.meshcount - 1 do
    local AMesh = GTray.root:getmesh(i)
    if AMesh.name == AName then
      AMesh.selected = true
      return
    end
  end
end

function apply_color()
  local ASelected  = GMesh.selectedindex
  local AName      = GMesh:getitemtext(ASelected)
  local AColorMesh = nil

  for i = 0, GTray.root.meshcount - 1 do
    local AMesh = GTray.root:getmesh(i)
    if AMesh.name == AName then
      AColorMesh = AMesh
    end
  end

  if AColorMesh ~= nil then
    local AColorIdx = GColor.selectedindex
    local AColor    = GColor:getitemtext(AColorIdx)

    if AColor ~= "" then
      AColor = string.sub(AColor, 2)
      AColorMesh.color = AColor
	  application:triggerdesktopevent('updateparts') 
    end
  else
    system:messagedlg("Selected Mesh not found.")
  end
end

GButtonClose = GDialog:addbutton()
GButtonClose.caption = "Close Form"
GButtonClose.translate = false
GButtonClose.onclick = "close_form"

GDialog:show()
