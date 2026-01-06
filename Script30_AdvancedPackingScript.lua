-- LUA Script for Autodesk Netfabb 2021.1
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes only
--==============================================================================

system:setloggingtooglwindow(true);

function getVolumeOfmesh(meshPar)
  local luamesh   = meshPar.mesh;
  local matrix   = meshPar.matrix;
  luamesh:applymatrix(matrix);
  return luamesh.volume;
end;

function insertMeshesIntoTable(meshgroup, Outtable)
  for mesh_index    = 0, meshgroup.meshcount - 1 do
      local traymesh      = meshgroup:getmesh(mesh_index);
      table.insert(Outtable, traymesh);
  end;
  for group_index = 0, meshgroup.groupcount - 1 do
     subgroup = meshgroup:getsubgroup(group_index);
     insertMeshesIntoTable(subgroup, Outtable);
  end;
end;

smartpackersettings = system:createsettingsgroup('smartpacker');
smartpackersettings:registerdoubleoption('Threshold_Large', 0, 10000000, 200* 1000);
smartpackersettings:registerdoubleoption('Threshold_Small', 0, 10000000, 50* 1000);
smartpackersettings:registerdoubleoption('CentralPackerOffset', 0, 100000, 100);

smartpackersettings:registerintegeroption('MontecarloAccuracy_Phase1', -8, 8, 0);
smartpackersettings:registerdoubleoption('MontecarloMinDistance_Phase1', 0, 10000, 0);
smartpackersettings:registerintegeroption('MontecarloPartRotation_Phase1', 0, 2, 2);
smartpackersettings:registerdoubleoption('MontecarloBorderspacez_Phase1', 0, 1000, 0);
smartpackersettings:registerintegeroption('MontecarloStartFromCurrentPosition_Phase1', 0, 1, 0);

smartpackersettings:registerintegeroption('MontecarloPartRotation_Phase2', 0, 2, 2);
smartpackersettings:registerdoubleoption('MontecarloBorderspacez_Phase2', 0, 1000, 0);
smartpackersettings:registerintegeroption('MontecarloStartFromCurrentPosition_Phase2', 0, 1, 0);
smartpackersettings:registerintegeroption('MontecarloAccuracy_Phase2', -8, 8, 0);
smartpackersettings:registerdoubleoption('MontecarloMinDistance_Phase2', 0, 10000, 0);
smartpackersettings:registerdoubleoption('MCPackerPhase2Border', 0, 10000, 0);


smartpackersettings:registerdoubleoption('SLBorder', 0, 10000, 0);
smartpackersettings:registerintegeroption('SL_Accuracy', 1, 5, 1);
smartpackersettings:registerintegeroption('SL_Voxelsize', 1, 5, 1);
smartpackersettings:registerintegeroption('SL_Interlockprotection', 0,1,0);
smartpackersettings:registerintegeroption('SL_RotationSteps', 0, 7 , 0);
smartpackersettings:registerintegeroption('SL_AllowFlip',0, 1, 0);

smartpackersettings:load();

local Threshold_Large = smartpackersettings:finddouble('Threshold_Large');
local Threshold_Small = smartpackersettings:finddouble('Threshold_Small');
local CentralPackerOffset = smartpackersettings:finddouble('CentralPackerOffset');

local MontecarloAccuracy_Phase1 = smartpackersettings:findinteger('MontecarloAccuracy_Phase1');
local MontecarloMinDistance_Phase1 = smartpackersettings:finddouble('MontecarloMinDistance_Phase1');
local MontecarloPartRotation_Phase1 = smartpackersettings:findinteger('MontecarloPartRotation_Phase1');
local MontecarloBorderspacez_Phase1 =  smartpackersettings:finddouble('MontecarloBorderspacez_Phase1');
local MontecarloStartFromCurrentPosition_Phase1 = smartpackersettings:findinteger('MontecarloStartFromCurrentPosition_Phase1');

local MontecarloAccuracy_Phase2 = smartpackersettings:findinteger('MontecarloAccuracy_Phase2');
local MontecarloMinDistance_Phase2 = smartpackersettings:finddouble('MontecarloMinDistance_Phase2');
local MCPackerPhase2Border = smartpackersettings:finddouble('MCPackerPhase2Border');
local MontecarloPartRotation_Phase2 = smartpackersettings:findinteger('MontecarloPartRotation_Phase2');
local MontecarloBorderspacez_Phase2 =  smartpackersettings:finddouble('MontecarloBorderspacez_Phase2');
local MontecarloStartFromCurrentPosition_Phase2 = smartpackersettings:findinteger('MontecarloStartFromCurrentPosition_Phase2');

local SLBorder = smartpackersettings:finddouble('SLBorder');
local SL_Accuracy = smartpackersettings:findinteger('SL_Accuracy');
local SL_Voxelsize = smartpackersettings:findinteger('SL_Voxelsize');
local SL_Interlockprotection = smartpackersettings:findinteger('SL_Interlockprotection');
local SL_RotationSteps = smartpackersettings:findinteger('SL_RotationSteps');
local SL_AllowFlip = smartpackersettings:findinteger('SL_AllowFlip');

local edit_CentralPacker = 0;
local edit_OutBoxThresholdA = 0;
local edit_OutBoxThresholdB = 0;
local edit_MontecarloMinDistance_Phase1  = 0;
local edit_MontecarloBorderspacez_Phase1  = 0;
local comboboxEfficeny_MC_Phase1  = 0;
local comboboxRotationConstraint_MC_Phase1  = 0;
local checkbox_MontecarloStartFromCurrentPosition_Phase1  = 0;
local edit_MontecarloMinDistance_Phase2  = 0;
local edit_MontecarloBorderspacez_Phase2  = 0;
local edit_MCPackerPhase2Border  = 0;
local comboboxEfficeny_MC_Phase2  = 0;
local checkbox_MontecarloStartFromCurrentPosition_Phase2  = 0;
local edit_SLBorder  = 0;
local combobox_Scaneline  = 0;
local combobox_SL_Voxelsize  = 0;
local combobox_SL_RotationSteps  = 0;
local checkbox_SL_Interlockprotection  = 0;
local checkbox_SL_AllowFlip  = 0;

function GetValuesFromGui () 
   CentralPackerOffset = tonumber(edit_CentralPacker.text);
   Threshold_Large = tonumber(edit_OutBoxThresholdA.text) * 1000;
   Threshold_Small = tonumber(edit_OutBoxThresholdB.text) * 1000;
	
   MontecarloMinDistance_Phase1 = tonumber(edit_MontecarloMinDistance_Phase1.text);
   MontecarloBorderspacez_Phase1 = tonumber(edit_MontecarloBorderspacez_Phase1.text);
   MontecarloAccuracy_Phase1 = comboboxEfficeny_MC_Phase1.selecteditem;
   MontecarloPartRotation_Phase1 = comboboxRotationConstraint_MC_Phase1.selecteditem;	
   if checkbox_MontecarloStartFromCurrentPosition_Phase1.checked then
     MontecarloStartFromCurrentPosition_Phase1 = 1;
   else
	 MontecarloStartFromCurrentPosition_Phase1 = 0;
   end;
    
   MontecarloMinDistance_Phase2 = tonumber(edit_MontecarloMinDistance_Phase2.text);
   MontecarloBorderspacez_Phase2 = tonumber(edit_MontecarloBorderspacez_Phase2.text);
   MCPackerPhase2Border =  tonumber(edit_MCPackerPhase2Border.text);
   MontecarloAccuracy_Phase2 = comboboxEfficeny_MC_Phase2.selecteditem;
   MontecarloPartRotation_Phase2 = comboboxRotationConstraint_MC_Phase2.selecteditem;
   if checkbox_MontecarloStartFromCurrentPosition_Phase2.checked then
	  MontecarloStartFromCurrentPosition_Phase2 = 1;
	else
	  MontecarloStartFromCurrentPosition_Phase2 = 0;
	end;
    
	SLBorder = tonumber(edit_SLBorder.text);
	SL_Accuracy = combobox_Scaneline.selecteditem;
	
	SL_Voxelsize = combobox_SL_Voxelsize.selecteditem;
    SL_RotationSteps = combobox_SL_RotationSteps.selecteditem;
    
	if checkbox_SL_Interlockprotection.checked then
	  SL_Interlockprotection = 1;
	else
	  SL_Interlockprotection = 0;
	end;
    
	if checkbox_SL_AllowFlip.checked then
	  SL_AllowFlip = 1;
	else
	  SL_AllowFlip = 0;
	end;
end;

function ValueAccuracyToComboBox(MontecarloAccuracy)

  if MontecarloAccuracy == 8 then
    return 0;
  end;
  if MontecarloAccuracy == 4 then
    return 1;
  end;
  if MontecarloAccuracy == 0 then
    return 2;
  end;
  if MontecarloAccuracy == -4 then
    return 3;
  end;
  if MontecarloAccuracy == -8 then
    return 4;
  end;
  return 2;
end;

function showmaindialog ()
  local dlg_width = 800;
  local dialog, edit, combobox, splitter, button;
  dialog = application:createdialog ();
  dialog.caption = "ADVPACKER_DIALOGCAPTION";
  dialog.width = dlg_width;
  dialog.translatecaption = true;
  maindialog = dialog;

  tabcontrol = maindialog:addtabcontrol();

  sheet = tabcontrol:addtabsheet();
  sheet.caption = "ADVPACKER_SHEETMAINSETTINGS";
  sheet.translate = true;

  local groupbox =  sheet:addgroupbox ();
  groupbox.caption = "ADVPACKER_MAINSETTINGS_GROUPBOXEXPLANATION_CAPTION"
  groupbox.translate = true;


  label = groupbox:addlabel ();
  label.caption = "ADVPACKER_MAINSETTINGS_GROUPBOXEXPLANATION_EXPLANATION1"
  label.translate = true;

  label = groupbox:addlabel ();
  label.caption = "ADVPACKER_MAINSETTINGS_GROUPBOXEXPLANATION_EXPLANATION2"
  label.translate = true;

  label = groupbox:addlabel ();
  label.caption = "ADVPACKER_MAINSETTINGS_GROUPBOXEXPLANATION_EXPLANATION3"
  label.translate = true;


  local groupboxSettings =  sheet:addgroupbox ();
  groupboxSettings.caption = "ADVPACKER_MAINSETTINGS_GROUPBOXSIZESETTING_CAPTION"
  groupboxSettings.translate = true;

  label = groupboxSettings:addlabel ();
  label.caption = "ADVPACKER_MAINSETTINGS_GROUPBOXSIZESETTING_DESCRIPTION"
  label.translate = true;

  edit = groupboxSettings:addedit ();
  edit.caption = "ADVPACKER_MAINSETTINGS_CENTRALAREADISTANCE";
  edit.captionwidth = 400;
  edit.translate = true;
  edit.text = tostring(CentralPackerOffset);
  edit_CentralPacker = edit;


  edit = groupboxSettings:addedit ();
  edit.caption = "ADVPACKER_MAINSETTINGS_VOLUMETHRESHOLDA";
  edit.captionwidth = 400;
  edit.translate = true;
  edit.text = tostring(Threshold_Large / 1000);
  edit_OutBoxThresholdA = edit;

  edit = groupboxSettings:addedit ();
  edit.caption = "ADVPACKER_MAINSETTINGS_VOLUMETHRESHOLDB";
  edit.captionwidth = 400;
  edit.translate = true;
  edit.text = tostring(Threshold_Small / 1000);
  edit_OutBoxThresholdB = edit;


  sheet = tabcontrol:addtabsheet();
  sheet.caption = "ADVPACKER_SHEETPACKERSETTINGS";
  sheet.translate = true;


  local groupboxMCPacker_Phase1 =  sheet:addgroupbox ();
  groupboxMCPacker_Phase1.caption = "ADVPACKER_PACKERETTINGS_MCPPHASE1"
  groupboxMCPacker_Phase1.translate = true;


  edit = groupboxMCPacker_Phase1:addedit ();
  edit.caption = "ADVPACKER_PACKERETTINGS_MINDISTBETWEENPART";
  edit.captionwidth = 300;
  edit.translate = true;
  edit.text = tostring(MontecarloMinDistance_Phase1);
  edit_MontecarloMinDistance_Phase1 = edit;

  edit = groupboxMCPacker_Phase1:addedit ();
  edit.caption = "ADVPACKER_PACKERETTINGS_DISTANCEPLATFORM";
  edit.captionwidth = 300;
  edit.translate = true;
  edit.text = tostring(MontecarloBorderspacez_Phase1);
  edit_MontecarloBorderspacez_Phase1 = edit;

  comboboxEfficeny_MC_Phase1 = groupboxMCPacker_Phase1:adddropdown ();
  comboboxEfficeny_MC_Phase1.caption = "FORM_MONTECARLOPACKER_PACKINGQUALITY";
  comboboxEfficeny_MC_Phase1.captionwidth = 300;
  comboboxEfficeny_MC_Phase1.translate = true;
  comboboxEfficeny_MC_Phase1:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_1", 8, 5,true, false);
  comboboxEfficeny_MC_Phase1:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_2", 4, 4,true, false);
  comboboxEfficeny_MC_Phase1:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_3", 0, 3,true, false);
  comboboxEfficeny_MC_Phase1:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_4", -4, 2,true, false);
  comboboxEfficeny_MC_Phase1:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_5", -8, 1,true, false);
  comboboxEfficeny_MC_Phase1.selecteditem = MontecarloAccuracy_Phase1;

  comboboxRotationConstraint_MC_Phase1 = groupboxMCPacker_Phase1:adddropdown ();
  comboboxRotationConstraint_MC_Phase1.caption = "FORM_MONTECARLOPACKER_ITEMROTATION";
  comboboxRotationConstraint_MC_Phase1.captionwidth = 300;
  comboboxRotationConstraint_MC_Phase1.translate = true;
  comboboxRotationConstraint_MC_Phase1:additem ("FORM_MONTECARLOPACKER_ITEMROTATION_ARBITRARY", 0, 3, true, false);
  comboboxRotationConstraint_MC_Phase1:additem ("FORM_MONTECARLOPACKER_ITEMROTATION_ZAXIS", 1, 2,true, false);
  comboboxRotationConstraint_MC_Phase1:additem ("FORM_MONTECARLOPACKER_ITEMROTATION_FORBIDDEN", 2, 1, true, false);
  comboboxRotationConstraint_MC_Phase1.selecteditem = MontecarloPartRotation_Phase1;

  checkbox = groupboxMCPacker_Phase1:addcheckbox ();
  checkbox.caption = "FORM_MONTECARLOPACKER_STARTFROMCURRENTPOSITIONS";
  checkbox.translate = true;
  checkbox_MontecarloStartFromCurrentPosition_Phase1 = checkbox;
  if MontecarloStartFromCurrentPosition_Phase1 == 1 then
     checkbox_MontecarloStartFromCurrentPosition_Phase1.checked = true;
  else
     checkbox_MontecarloStartFromCurrentPosition_Phase1.checked = false;
  end;



  local groupboxMCPacker_Phase2 =  sheet:addgroupbox ();
  groupboxMCPacker_Phase2.caption = "ADVPACKER_PACKERETTINGS_MCPPHASE2"
  groupboxMCPacker_Phase2.translate = true;


  edit = groupboxMCPacker_Phase2:addedit ();
  edit.caption = "ADVPACKER_PACKERETTINGS_MINDISTBETWEENPART";
  edit.captionwidth = 300;
  edit.translate = true;
  edit.text = tostring(MontecarloMinDistance_Phase2);
  edit_MontecarloMinDistance_Phase2 = edit;

  edit = groupboxMCPacker_Phase2:addedit ();
  edit.caption = "ADVPACKER_PACKERETTINGS_DISTANCESIDEWALLS";
  edit.captionwidth = 300;
  edit.translate = true;
  edit.text = tostring(MCPackerPhase2Border);
  edit_MCPackerPhase2Border = edit;

  edit = groupboxMCPacker_Phase2:addedit ();
  edit.caption = "ADVPACKER_PACKERETTINGS_DISTANCEPLATFORM";
  edit.captionwidth = 300;
  edit.translate = true;
  edit.text = tostring(MontecarloBorderspacez_Phase2);
  edit_MontecarloBorderspacez_Phase2 = edit;


  comboboxEfficeny_MC_Phase2 = groupboxMCPacker_Phase2:adddropdown ();
  comboboxEfficeny_MC_Phase2.caption = "FORM_MONTECARLOPACKER_PACKINGQUALITY";
  comboboxEfficeny_MC_Phase2.captionwidth = 300;
  comboboxEfficeny_MC_Phase2.translate = true;
  comboboxEfficeny_MC_Phase2:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_1", 8, 5,true, false);
  comboboxEfficeny_MC_Phase2:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_2", 4, 4,true, false);
  comboboxEfficeny_MC_Phase2:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_3", 0, 3,true, false);
  comboboxEfficeny_MC_Phase2:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_4", -4, 2,true, false);
  comboboxEfficeny_MC_Phase2:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_5", -8, 1,true, false);
  comboboxEfficeny_MC_Phase2.selecteditem = MontecarloAccuracy_Phase2;

  comboboxRotationConstraint_MC_Phase2 = groupboxMCPacker_Phase2:adddropdown ();
  comboboxRotationConstraint_MC_Phase2.caption = "FORM_MONTECARLOPACKER_ITEMROTATION";
  comboboxRotationConstraint_MC_Phase2.captionwidth = 300;
  comboboxRotationConstraint_MC_Phase2.translate = true;
  comboboxRotationConstraint_MC_Phase2:additem ("FORM_MONTECARLOPACKER_ITEMROTATION_ARBITRARY", 0, 3, true, false);
  comboboxRotationConstraint_MC_Phase2:additem ("FORM_MONTECARLOPACKER_ITEMROTATION_ZAXIS", 1, 2,true, false);
  comboboxRotationConstraint_MC_Phase2:additem ("FORM_MONTECARLOPACKER_ITEMROTATION_FORBIDDEN", 2, 1, true, false);
  comboboxRotationConstraint_MC_Phase2.selecteditem = MontecarloPartRotation_Phase2;



  checkbox = groupboxMCPacker_Phase2:addcheckbox ();
  checkbox.caption = "FORM_MONTECARLOPACKER_STARTFROMCURRENTPOSITIONS";
  checkbox.translate = true;
  checkbox_MontecarloStartFromCurrentPosition_Phase2 = checkbox;
  if MontecarloStartFromCurrentPosition_Phase2 == 1 then
     checkbox_MontecarloStartFromCurrentPosition_Phase2.checked = true;
  else
     checkbox_MontecarloStartFromCurrentPosition_Phase2.checked = false;
  end;

  
  local groupboxScanLinePacker =  sheet:addgroupbox ();
  groupboxScanLinePacker.caption = "ADVPACKER_PACKERETTINGS_SLPHASE3"
  groupboxScanLinePacker.translate = true;
  

  combobox_SL_Voxelsize = groupboxScanLinePacker:adddropdown ();
  combobox_SL_Voxelsize.caption = "FORM_DEFAULT_3DPACKING_GRIDSIZE";
  combobox_SL_Voxelsize.captionwidth = 300;
  combobox_SL_Voxelsize.translate = true;
  combobox_SL_Voxelsize:additem ("1 mm", 1, 1,false, false);
  combobox_SL_Voxelsize:additem ("2 mm", 2, 2,false, false);
  combobox_SL_Voxelsize:additem ("3 mm", 3, 3,false, false);
  combobox_SL_Voxelsize:additem ("4 mm", 4, 4,false, false);
  combobox_SL_Voxelsize:additem ("5 mm", 5, 5,false, false);
  combobox_SL_Voxelsize.selecteditem = SL_Voxelsize;

  combobox_SL_RotationSteps = groupboxScanLinePacker:adddropdown ();
  combobox_SL_RotationSteps.caption = "FORM_DEFAULT_3DPACKING_ZROTATION";
  combobox_SL_RotationSteps.captionwidth = 300;
  combobox_SL_RotationSteps.translate = true;
  combobox_SL_RotationSteps:additem ("ADVPACKER_PACKERETTINGS_SL_ROTATIONSTEPS0", 0, 0,true, false);
  combobox_SL_RotationSteps:additem ("ADVPACKER_PACKERETTINGS_SL_ROTATIONSTEPS1", 1, 1,true, false);
  combobox_SL_RotationSteps:additem ("ADVPACKER_PACKERETTINGS_SL_ROTATIONSTEPS2", 2, 2,true, false);
  combobox_SL_RotationSteps:additem ("ADVPACKER_PACKERETTINGS_SL_ROTATIONSTEPS3", 3, 3,true, false);
  combobox_SL_RotationSteps:additem ("ADVPACKER_PACKERETTINGS_SL_ROTATIONSTEPS4", 4, 4,true, false);
  combobox_SL_RotationSteps:additem ("ADVPACKER_PACKERETTINGS_SL_ROTATIONSTEPS5", 5, 5,true, false);
  combobox_SL_RotationSteps:additem ("ADVPACKER_PACKERETTINGS_SL_ROTATIONSTEPS6", 6, 6,true, false);
  combobox_SL_RotationSteps:additem ("ADVPACKER_PACKERETTINGS_SL_ROTATIONSTEPS7", 7, 7,true, false);
  combobox_SL_RotationSteps.selecteditem = SL_RotationSteps;

  edit = groupboxScanLinePacker:addedit ();
  edit.caption = "ADVPACKER_PACKERETTINGS_DISTANCESIDEWALLS";
  edit.captionwidth = 300;
  edit.translate = true;
  edit.text = tostring(SLBorder);
  edit_SLBorder = edit;
 
  combobox_Scaneline = groupboxScanLinePacker:adddropdown ();
  combobox_Scaneline.caption = "FORM_MONTECARLOPACKER_PACKINGQUALITY";
  combobox_Scaneline.captionwidth = 300;
  combobox_Scaneline.translate = true;
  combobox_Scaneline:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_1", 1, 5, true, false);
  combobox_Scaneline:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_2", 2, 4, true, false);
  combobox_Scaneline:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_3", 3, 3, true, false);
  combobox_Scaneline:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_4", 4, 2, true, false);
  combobox_Scaneline:additem ("FORM_MONTECARLOPACKER_PACKINGQUALITY_5", 5, 1, true, false);
  combobox_Scaneline.selecteditem = SL_Accuracy;

  checkbox = groupboxScanLinePacker:addcheckbox ();
  checkbox.caption = "FORM_DEFAULT_3DPACKING_INTERLOCKINGPROTECTION";
  checkbox.translate = true;
  checkbox_SL_Interlockprotection = checkbox;
  if SL_Interlockprotection == 1 then
     checkbox_SL_Interlockprotection.checked = true;
  else
     checkbox_SL_Interlockprotection.checked = false;
  end;

  checkbox = groupboxScanLinePacker:addcheckbox ();
  checkbox.caption = "FORM_DEFAULT_3DPACKING_FLIPUPSIDEDOWN";
  checkbox.translate = true;
  checkbox_SL_AllowFlip = checkbox;
  if SL_AllowFlip == 1 then
     checkbox_SL_AllowFlip.checked = true;
  else
     checkbox_SL_AllowFlip.checked = false;
  end;

  sheet = tabcontrol:addtabsheet();
  sheet.caption = "ADVPACKER_HISTOGRAM_CAPTION";
  sheet.translate = true;

  histogram = system:createhistogram();
  histogram.showmedian = true;
  histogram.translate = true;
  histogram.caption_x = "ADVPACKER_HISTOGRAM_VOLUME";
  histogram.caption_y = "ADVPACKER_HISTOGRAM_OCCURENCE";
  histogram.bar_count = 25;
  histogram.unit = ' cm3';

  local meshesAll = {};
  local root = tray.root;
  local meshesAll = {};
  insertMeshesIntoTable(root, meshesAll);

  for i, traymesh in pairs(meshesAll) do
      histogram:addvalue(traymesh.volume / 1000);
  end;

  image = sheet:addimage ();
  image.width = dlg_width - 15
  image.height = 300
  local histogram_image = histogram:drawhistogram(image.width, image.height);
  image:setimage(histogram_image);

  label = dialog:addlabel ();
  label.caption = "";
  label.translate = false;


  splitter = dialog:addsplitter (true,300);
  splitter:settoleft ();
  button = splitter:addbutton ();
  button.caption = "GENERAL_START";
  button.translate = true;
  button.onclick = "maindialog_ok";
  splitter:settoright ();
  button = splitter:addbutton ();
  button.caption = "GENERAL_CANCEL";
  button.translate = true;
  button.onclick = "maindialog_oncancel";

  if dialog:show () then     
	return true;
  end;
end;

function VerifyValues()
  local result = true;
  local outboxTray = tray.outbox;

  local sizeX = outboxTray.maxx - outboxTray.minx;
  local sizeY = outboxTray.maxy - outboxTray.miny;
  
  size = sizeX
  if (size > sizeY) then
     size = sizeY;
  end;
  
    
   if (CentralPackerOffset < 0) then
      system:messagedlg("Size Sorting Packer Error: Distance to sidewalls for central area is negative");
      return false;
   end;
   
   if (CentralPackerOffset > (size / 2.0) ) then
      system:messagedlg("Size Sorting Packer Error: Distance to sidewalls for central area is larger than the tray size allows");
      return false;
   end;
    
   if (Threshold_Large < 0) then
      system:messagedlg("Size Sorting Packer Error: Threshold A is negative");
      return false;
   end;
   
   if (Threshold_Small < 0) then
      system:messagedlg("Size Sorting Packer Error: Threshold B is negative");
      return false;
   end;
   
   if (Threshold_Large < Threshold_Small) then
      system:messagedlg("Threshold B larger than Threshold A");
      return false;
   end;

   
   if (MontecarloMinDistance_Phase1 < 0) then
      system:messagedlg("Size Sorting Packer Error: Phase 1 distance between parts is negative");
      return false;
   end;
   
   if (MontecarloBorderspacez_Phase1 < 0) then
      system:messagedlg("Size Sorting Packer Error: Phase 1 distance to platform z is negative");
      return false;
   end;
   
   if (MontecarloMinDistance_Phase2 < 0) then
      system:messagedlg("Size Sorting Packer Error: Phase 2 distance between parts is negative");
      return false;
   end;
   
   if (MontecarloBorderspacez_Phase2 < 0) then
      system:messagedlg("Size Sorting Packer Error: Phase 2 distance to platform z is negative");
      return false;
   end; 
   
   if (MCPackerPhase2Border < 0) then
      system:messagedlg("Size Sorting Packer Error: Phase 2 distance to border xy is negative");
      return false;
   end; 
   
   if (MCPackerPhase2Border > (size / 2.0) ) then
      system:messagedlg("Size Sorting Packer Error: Phase 2 distance to border xy is larger than the tray size allows");
      return false;
   end;   
   
   if (SLBorder < 0) then
      system:messagedlg("Size Sorting Packer Error: Phase 3 distance to sidewalls xy is negative");
      return false;
   end;    
   
   if (SLBorder > (size / 2.0) ) then
      system:messagedlg("Size Sorting Packer Error: Phase 3 distance to border xy is larger than the tray size allows");
      return false;
   end;   
      
    
   return true;	
end;

function maindialog_ok ()
  GetValuesFromGui(); 
  if VerifyValues() then  
    maindialog:close (true);
  end;
end;

function maindialog_oncancel ()
  maindialog:close (false);
end;

function MoveMatrixZ(matrix, value)
  local tmp = matrix:get(2,2)
  matrix:set(3, 2, tmp + value);
end;

function checkErrorCodeMCpacker(text, errorcodepar)
  if errorcodepar == 0 then
    system:log(text .. ': Monte Carlo Packing is finished. No problems were detected.');
    saveproject=true;
  elseif errorcodepar == 1 then
    system:log(text .. ': Monte Carlo Packing is finished. There is not enough place for all parts in the tray.');
    saveproject=true;
  elseif errorcodepar == 2 then
    system:log(text .. ': Monte Carlo Packing is finished. Some parts are too large for the given tray.');
    saveproject=true;
  elseif errorcodepar == 3 then
    system:log(text .. ': Monte Carlo Packing failed: All parts are too large for the given tray.');
  elseif errorcodepar == 4 then
    system:log(text .. ': Monte Carlo Packing failed: There are no parts to pack.');
  elseif errorcodepar == 5 then
    system:log(text .. ': Monte Carlo Packing failed: Starting from current positions is not possible.');
  else
    system:log(text .. ': Monte Carlo Packing failed: Unknown error. ');
  end;
end;

function montecarlopacker (meshAll)
  local defaultpartrotation = 'arbitrary'; -- Possible values: 'arbitrary', 'zaxisonly', 'forbidden'
  --local mindist = MontecarloMinDistance;
  --local packingquality_Phase1 = MontecarloAccuracy_Phase1; -- Updated packer quality
  local PackerResize = CentralPackerOffset;

  local packer = tray:createpacker(tray.packingid_montecarlo);
  local packerAll = tray:createpacker(tray.packingid_montecarlo);
  local outboxOrig = packer:getoutbox();
  local outbox = packer:getoutbox();

  local tempMaxX = outbox.maxx;
  local tempMaxY = outbox.maxy;

  outbox.minx = PackerResize;
  outbox.miny = PackerResize;

  outbox.maxx = tempMaxX - PackerResize;
  outbox.maxy = tempMaxY - PackerResize;

  packer:setoutbox(outbox);

  -- Setting options in the Monte Carlo packer
  packer.defaultpartrotation = MontecarloPartRotation_Phase1;
  packer.packing_quality = MontecarloAccuracy_Phase1;
  packer.borderspacingz  = MontecarloBorderspacez_Phase1;
  packer.start_from_current_positions = MontecarloStartFromCurrentPosition_Phase1;
  packer.minimaldistance = tonumber(MontecarloMinDistance_Phase1);
  packer.enableignoreparts = true;
  packer.borderspacingxy = 0;
  for i, traymesh in pairs(meshAll) do
    local matrix = traymesh.matrix;
    MoveMatrixZ(matrix, 1000);
    traymesh:setmatrix(matrix);
  end;
  for i, traymesh in pairs(meshAll) do
    if (traymesh.volume < Threshold_Large) then
      traymesh:setpackingoption('ignoreforluapacking', 'true');
    else
      traymesh:setpackingoption('ignoreforluapacking', 'false');
    end;
  end;
  --Pack large things
  system:setprogresscancancel(10,'First Phase');
  local errorcode=packer:pack();
  checkErrorCodeMCpacker('First phase' , errorcode);

  for i, traymesh in pairs(meshAll) do
    result = traymesh:getpackingoption('state');
    if (result ~= 'packed') then
      traymesh:translate(CentralPackerOffset*2, CentralPackerOffset*2, 0);
    end;
  end;

  --Now pack small things
  packer:setoutbox(outboxOrig);
  for i, traymesh in pairs(meshAll) do
    if (traymesh.volume < Threshold_Large) and (traymesh.volume > Threshold_Small) then
       traymesh:setpackingoption('restriction', 'norestriction');
    else
       traymesh:setpackingoption('restriction', 'locked');
    end;
    if (traymesh.volume < Threshold_Small) then
      traymesh:setpackingoption('ignoreforluapacking', 'true');
    else
      traymesh:setpackingoption('ignoreforluapacking', 'false');
    end;
  end;
  packer.borderspacingxy = MCPackerPhase2Border;
  packer.borderspacingz = MontecarloBorderspacez_Phase2;
  packer.packing_quality = MontecarloAccuracy_Phase2;
  packer.minimaldistance = tonumber(MontecarloMinDistance_Phase2);

  system:setprogresscancancel(40,'Second Phase');
  local errorcode=packer:pack();
  checkErrorCodeMCpacker('Second phase' , errorcode);
end;

function scanline (meshesOrig)

  for i, traymesh in pairs(meshesOrig) do
    if (traymesh.volume < Threshold_Small) then
          traymesh:setpackingoption('restriction', 'norestriction');
    else
          traymesh:setpackingoption('restriction', 'locked');
    end;
  end;

  local packer = tray:createpacker(tray.packingid_3d);
   
  packer.allowrotationaxis =  SL_AllowFlip;
  packer.interlockingprotection = SL_Interlockprotection;
  packer.anglecount = SL_RotationSteps;
  packer.rastersize = SL_Voxelsize;
  
  packer.coarsening = SL_Accuracy+1;
  packer.placeoutside = false;
  packer.borderspacingxy = SLBorder;
  system:setprogresscancancel(60,'Third Phase');
  local errorcode=packer:pack();
  if errorcode == 0 then
    system:log('Third phase: packing done');
  elseif errorcode == 1 then
    system:log('Third phase: packing error');
  else
    system:log('Packing failed: Unknown error. Please contact the support team.');
  end;

end;

--Run Dialogs
if showmaindialog () then
   if tray == nil then
     system:log('  tray is nil!');
   else
     smartpackersettings:setdouble('Threshold_Large', Threshold_Large);
     smartpackersettings:setdouble('Threshold_Small', Threshold_Small);
     smartpackersettings:setdouble('CentralPackerOffset', CentralPackerOffset);
     
	 smartpackersettings:setinteger('MontecarloAccuracy_Phase1', MontecarloAccuracy_Phase1);
     smartpackersettings:setdouble('MontecarloMinDistance_Phase1', MontecarloMinDistance_Phase1);
	 smartpackersettings:setinteger('MontecarloPartRotation_Phase1', MontecarloPartRotation_Phase1);
	 smartpackersettings:setdouble('MontecarloBorderspacez_Phase1', MontecarloBorderspacez_Phase1);
     smartpackersettings:setinteger('MontecarloStartFromCurrentPosition_Phase1', MontecarloStartFromCurrentPosition_Phase1);

     smartpackersettings:setinteger('MontecarloAccuracy_Phase2', MontecarloAccuracy_Phase2);
     smartpackersettings:setdouble('MontecarloMinDistance_Phase2', MontecarloMinDistance_Phase2);
	 smartpackersettings:setinteger('MontecarloPartRotation_Phase2', MontecarloPartRotation_Phase2);
	 smartpackersettings:setdouble('MontecarloBorderspacez_Phase2', MontecarloBorderspacez_Phase2);
     smartpackersettings:setinteger('MontecarloStartFromCurrentPosition_Phase2', MontecarloStartFromCurrentPosition_Phase2);
     smartpackersettings:setdouble('MCPackerPhase2Border', MCPackerPhase2Border);

     smartpackersettings:setdouble('SLBorder', SLBorder);
     smartpackersettings:setinteger('SL_Accuracy', SL_Accuracy);
	
	 smartpackersettings:setinteger('SL_Voxelsize', SL_Voxelsize);
     smartpackersettings:setinteger('SL_Interlockprotection', SL_Interlockprotection);
     smartpackersettings:setinteger('SL_RotationSteps', SL_RotationSteps);
     smartpackersettings:setinteger('SL_AllowFlip',SL_AllowFlip );    
	
     system:showprogressdlgcancancel(false);
     smartpackersettings:save();
     local root = tray.root;

     local meshesAll = {};
     insertMeshesIntoTable(root, meshesAll);
	 for mesh_index    = 0, root.meshcount - 1 do
       local traymesh = root:getmesh(mesh_index);
       table.insert(meshesAll, traymesh);
     end;
     for i, traymesh in pairs(meshesAll) do
        traymesh:setpackingoption('restriction', 'norestriction');
     end;
     montecarlopacker (meshesAll);

     scanline (meshesAll);
     system:hideprogressdlgcancancel();
   end;
end;
                          