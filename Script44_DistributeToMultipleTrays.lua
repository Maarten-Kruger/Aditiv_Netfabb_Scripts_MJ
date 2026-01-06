-- LUA Script for Autodesk Netfabb 2024
-- Copyright by Autodesk 2023
-- This script is for demonstration purposes
--==============================================================================
-- This script is for the LUA Automation module in the main module
-- Goes through the meshes in the tray distributes them acrtoss multiple trays based on a zCut input

-- Dialog
-- Creatig and displaying the Dialog
dialog = application:createdialog();
dialog.caption = "Distribute";
dialog.translatecaption = false

-- Add an editable dialog entry
dialog_Zheight = dialog:addedit()
dialog_Zheight.caption = "Z (mm)"
dialog_Zheight.captionwidthpercentage = 75
dialog_Zheight.customcolor = '$FFFFFF'
dialog_Zheight.enabled = true
dialog_Zheight.readonly = false
dialog_Zheight.numbersonly = true
dialog_Zheight.height = 100
dialog_Zheight.hint = "Z height of the Platform"
dialog_Zheight.text = "294.4"
dialog_Zheight.spacing = 4
dialog_Zheight.topspacing = 1
dialog_Zheight.translate = false

dialog_NewTrayName = dialog:addedit()
dialog_NewTrayName.caption = "Tray Name"
dialog_NewTrayName.captionwidthpercentage = 75
dialog_NewTrayName.customcolor = '$FFFFFF'
dialog_NewTrayName.enabled = true
dialog_NewTrayName.readonly = false
dialog_NewTrayName.numbersonly = false
dialog_NewTrayName.height = 100
dialog_NewTrayName.hint = "New Tray Name"
dialog_NewTrayName.text = "Fuse 1"
dialog_NewTrayName.spacing = 4
dialog_NewTrayName.topspacing = 1
dialog_NewTrayName.translate = false

insertMeshesIntoTable = function (meshgroup, Outtable)
  for mesh_index    = 0, meshgroup.meshcount - 1 do
      local traymesh      = meshgroup:getmesh(mesh_index);
      table.insert(Outtable, traymesh);
  end;
  for group_index = 0, meshgroup.groupcount - 1 do
    subgroup = meshgroup:getsubgroup(group_index);
    insertMeshesIntoTable(subgroup, Outtable);
  end;
end;

insertMeshesIntoTableWithZCut = function (meshgroup, Outtable, zCut)
  for mesh_index    = 0, meshgroup.meshcount - 1 do
      local traymesh      = meshgroup:getmesh(mesh_index);
      if traymesh.outbox.maxz < zCut then
        table.insert(Outtable, traymesh);
      end;
  end;
  for group_index = 0, meshgroup.groupcount - 1 do
    subgroup = meshgroup:getsubgroup(group_index);
    insertMeshesIntoTable(subgroup, Outtable);
  end;
end;

function moveMeshesToTray(meshtable, zCut)
    local min_height = zCut;
    for i, traymesh in pairs(meshtable) do
      if traymesh.outbox.minz < min_height then
          min_height = traymesh.outbox.minz;
      end;
    end;
    for i, traymesh in pairs(meshtable) do
      traymesh:translate(0,0, -min_height); -- feel free to add + 1 mm to Z if needed
    end;
end;

function removemeshes (meshtable)
  for i, traymesh in pairs(meshtable) do
    local meshgroup = traymesh.parent;
    meshgroup:removemesh(traymesh);
  end;
end;
function copy2tray(meshtable, targettray)
  for i, traymesh in pairs(meshtable) do
    local luamesh = traymesh.mesh;
    local matrix = traymesh.matrix;
    luamesh:applymatrix(matrix);
    targettray.root:addmesh(luamesh,traymesh.name);
  end;
end;
function lengthoftable(meshtable)
  length = 0
  for i, traymesh in pairs(meshtable) do
    length = length + 1
  end;
  return length;
end;

function dialog_distribute_onOkClick()
  system:setloggingtooglwindow(true);
  local zCut = tonumber(dialog_Zheight.text);
  local totaltrays = math.ceil(tray.filling_height_all/zCut);
  local newtrayname = dialog_NewTrayName.text
  dialog:close (false)

  ---- DO ---
  if tray == nil then
      system:log('  tray is nil!');
    else
      -- Get root meshgroup from tray
      local root = tray.root;
      NotFinished = true;
      -- Collect meshes in the tray
      local nameCounter = 1
      system:showprogressdlgcancancel(true);
      while NotFinished do
        system:setprogresscancancel(nameCounter*100/totaltrays, 'Creating tray ' .. nameCounter, false); -- displays a progress with cancel option
        local meshesZCut = {};
        insertMeshesIntoTableWithZCut(root, meshesZCut, zCut);
        local name = newtrayname .. "_" .. tostring(nameCounter);
        local tmptray = netfabbtrayhandler:addtray(name, tray.machinesize_x,tray.machinesize_y,dialog_Zheight.text); 
        copy2tray(meshesZCut, tmptray);
        removemeshes(meshesZCut);
        local meshes = {};
        nameCounter = nameCounter + 1;
        insertMeshesIntoTable(root, meshes);
        moveMeshesToTray(meshes, zCut);
        if lengthoftable(meshes) < 1 then
            NotFinished = false;
        end;
        if nameCounter > 100 then
          NotFinished = false;
        end;
        isCancel = system:progresscancelled();
        if isCancel then                      -- Defines cancel behaiour
          system:log('Automation canceled');
          break;
        end;  
      end;
      system:hideprogressdlgcancancel();
    end;
  end;

  
function dialog_distribute_oncancelclick()
  dialog:close (false)
end;

splitter = dialog:addsplitter()
splitter:settoleft()
button = splitter:addbutton()
button.caption = "GENERAL_OK"
button.onclick = "dialog_distribute_onOkClick"
splitter:settoright()
button = splitter:addbutton()
button.caption = "GENERAL_CANCEL"
button.onclick = "dialog_distribute_oncancelclick"
dialog:show()