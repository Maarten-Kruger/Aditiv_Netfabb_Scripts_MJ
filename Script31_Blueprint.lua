GTray = netfabbtrayhandler:gettray(0)
GMesh = nil

for i = 0, GTray.root.meshcount - 1 do
  local AMesh = GTray.root:getmesh(i)
  if AMesh.selected then
    if GMesh ~= nil then
      system:messagedlg("Only one mesh must be selected.")
      return
    else
      GMesh = AMesh
    end
  end
end

if GMesh == nil then
  system:messagedlg("No mesh was selected.")
  return
end


dialog = application:createdialog()
dialog.caption = "Create Blueprint"
dialog.translatecaption = false

drawgrid = dialog:addcheckbox()
drawgrid.checked = true
drawgrid.caption = "Draw Meshgrid"
drawgrid.translate = false
drawgrid.onclick = "drawgrid_clicked"

division = dialog:adddropdown()
division.caption = "Division"
division.captionwidth = 120
division.translate = false
division:additem("No Division", 0, 0, false)
division:additem("One Centimeter", 1, 1, false)
division:additem("Five Centimeter", 2, 2, false)
division:additem("Ten Centimeter", 3, 3, false)

subdivision = dialog:adddropdown()
subdivision.caption = "Subdivision"
subdivision.captionwidth = 120
subdivision.translate = false
subdivision:additem("No Division", 0, 0, false)
subdivision:additem("One Millimeter", 1, 1, false)
subdivision:additem("Two Millimeter", 2, 2, false)
subdivision:additem("Five Millimeter", 3, 3, false)
subdivision:additem("One Centimeter", 4, 4, false)
subdivision:additem("Two Centimeter", 5, 5, false)
subdivision:additem("Five Centimeter", 6, 6, false)

projection = dialog:adddropdown()
projection.caption = "Projection"
projection.captionwidth = 120
projection.translate = false
projection:additem("Y/Z Plane", 0, 0, false)
projection:additem("X/Z Plane", 1, 1, false)
projection:additem("X/Y Plane", 2, 2, false)

paperstandard = dialog:adddropdown()
paperstandard.caption = "Paper Standard"
paperstandard.captionwidth = 120
paperstandard.translate = false
paperstandard:additem("ISO 216A", 0, 0, false)
paperstandard:additem("ANSI", 1, 1, false)
paperstandard:additem("Custom", 2, 2, false)
paperstandard.onchange = 'paperstandard_change'

papersize = dialog:adddropdown()
papersize.caption = "Paper Size"
papersize.captionwidth = 120
papersize.translate = false

paperwidth = dialog:addedit()
paperwidth.caption = "Paper Width"
paperwidth.captionwidth = 120
paperwidth.translate = false

paperheight = dialog:addedit()
paperheight.caption = "Paper Height"
paperheight.captionwidth = 120
paperheight.translate = false

drawshadowarea = dialog:addcheckbox()
drawshadowarea.checked = true
drawshadowarea.caption = "Draw Shadow Area"
drawshadowarea.translate = false
drawshadowarea.onclick = "drawgrid_clicked"



splitter = dialog:addsplitter()
splitter:settoleft()

button = splitter:addbutton()
button.caption = "GENERAL_OK"
button.onclick = "ok_clicked"

splitter:settoright()

button = splitter:addbutton()
button.caption = "GENERAL_CANCEL"
button.onclick = "cancel_clicked"

function ok_clicked()
  dialog:close(true);
end

function cancel_clicked()
  dialog:close(false);
end

function paperstandard_change()
  if paperstandard.selecteditem == 0 then
    papersize.enabled = true
    papersize:clear()
    papersize:additem("DIN A0", 0, 0, false)
    papersize:additem("DIN A1", 1, 1, false)
    papersize:additem("DIN A2", 2, 2, false)
    papersize:additem("DIN A3", 3, 3, false)
    papersize:additem("DIN A4", 4, 4, false)
    papersize:updateitems()
    
    paperwidth .enabled = false
    paperheight.enabled = false
  elseif paperstandard.selecteditem == 1 then
    papersize.enabled = true
    papersize:clear()
    papersize:additem("ANSI E", 0, 0, false)
    papersize:additem("ANSI D", 1, 1, false)
    papersize:additem("ANSI C", 2, 2, false)
    papersize:additem("ANSI B", 3, 3, false)
    papersize:additem("ANSI A", 4, 4, false)
    papersize:updateitems()
    
    paperwidth .enabled = false
    paperheight.enabled = false
  elseif paperstandard.selecteditem == 2 then
    papersize  .enabled = false
    paperwidth .enabled = true
    paperheight.enabled = true
  end
end

function drawgrid_clicked()
  local AEnabled = drawgrid.checked
  
  division   .enabled = AEnabled
  subdivision.enabled = AEnabled
end

paperstandard_change()

if dialog:show() then
  AFileName = system:showopendialog("*.pdf")
  
  if AFileName ~= "" then
    local ABlueprint = system:createblueprintcreator(GMesh.mesh)
    
    ABlueprint.division      = division     .selecteditem
    ABlueprint.subdivision   = subdivision  .selecteditem
    ABlueprint.projection    = projection   .selecteditem
    ABlueprint.paperstandard = paperstandard.selecteditem
    ABlueprint.papersize     = papersize    .selecteditem
    
    if paperstandard.selecteditem == 2 then
      ABlueprint.paperwidth  = tonumber(paperwidth .text)
      ABlueprint.paperheight = tonumber(paperheight.text)
    end
    
    ABlueprint.drawmeshgrid   = drawgrid      .checked
    ABlueprint.drawshadowarea = drawshadowarea.checked
    
    ABlueprint:saveblueprint(AFileName)
  end
end
