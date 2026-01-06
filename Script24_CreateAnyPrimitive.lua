-- LUA Script for Autodesk Netfabb 2019.1
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- It allows the user to generate a mesh from the part library

handler = system:createprimitivelist();
primitive = nil;
dialog_list = nil;
dialog_options = nil;
dropdown_primitive = nil;
settings = nil;
primitive_name_map = nil;

function DoCreate ()
  if primitive ~= nil then
    for i, setting in pairs(settings) do
      primitive:setsettingvalue(i, setting.text);
    end
    local mesh = primitive:generatemesh();
    local root = tray.root;
    root:addmeshsource(mesh, primitive.name, primitive.color);
  end;
  DoCancel();
end;

function DoCancel ()
  system:log('canceled by user');
  if dialog_list ~= nil then
    dialog_list:close (false);
  end;
  if dialog_options ~= nil then
    dialog_options:close (false);
  end;
end;

function ShowOptions ()
  system:log('show primitive options');
  if dialog_list ~= nil then
    dialog_list:close (false);
    dialog_list = nil;
  end;

  name = primitive_name_map[dropdown_primitive.selectedindex];
  primitive = handler:createprimitive(name);
  
  -- primitive index order can change for releases, better use name
  -- primitive = handler:createprimitivebyindex(dropdown_primitive.selectedindex);

  dialog_options = application:createdialog ();
  dialog_options.caption = "Configure " .. name
  dialog_options.width = 350;
  dialog_options.translatecaption = false;

  local groupbox =  dialog_options:addgroupbox ();
  groupbox.caption = "Settings for " .. name
  groupbox.translate = false;

  settings = {};
  for i=0, primitive.settingcount-1 do
    edit = groupbox:addedit();
    edit.caption = primitive:getsettingname(i);
    edit.captionwidth = 150;
    edit.translate = false;
    edit.text = primitive:getsettingvalue(i);
    settings[i] = edit;
  end;

  local splitter = groupbox:addsplitter ();
  splitter:settoleft ();
  local button = splitter:addbutton ();
  button.caption = "Create";
  button.translate = false;
  button.onclick = "DoCreate";

  splitter:settoright ();
  button = splitter:addbutton ();
  button.caption = "Cancel";
  button.translate = false;
  button.onclick = "DoCancel";

  if dialog_options:show () then
    return true;
  end;
    return false;
end;

function ShowList ()
  system:log('show primitive list');

  dialog_list = application:createdialog ();
  dialog_list.caption = "Primitive list"
  dialog_list.width = 300;
  dialog_list.translatecaption = false;

  local groupbox =  dialog_list:addgroupbox ();
  groupbox.caption = ""
  groupbox.translate = false;

  primitive_name_map = {};
  dropdown_primitive = groupbox:adddropdown ();
  dropdown_primitive.caption = "Primitive";
  dropdown_primitive.captionwidth = 100;
  dropdown_primitive.translate = false;
  for i=0, handler.count-1 do
    dropdown_primitive:additem(handler:getname(i), i, i, false);
    primitive_name_map[i] = handler:getname(i);
  end;

  local splitter = groupbox:addsplitter ();
  splitter:settoleft ();
  local button = splitter:addbutton ();
  button.caption = "Next";
  button.translate = false;
  button.onclick = "ShowOptions";

  splitter:settoright ();
  button = splitter:addbutton ();
  button.caption = "Cancel";
  button.translate = false;
  button.onclick = "DoCancel";

  if dialog_list:show () then
    return true;
  end;
    return false;
end;

ShowList();