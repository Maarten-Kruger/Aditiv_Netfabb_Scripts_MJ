-- LUA Script for Autodesk Netfabb
-- Copyright by Autodesk 2022
-- This script is for demonstration purposes
--==============================================================================

-- This script shows how to create packer, which packs only selected parts and puts them into an package 


system:executescriptfile ("Examples\\\\LUA Scripts\\\\BaseRoutines.lua");
system:setloggingtooglwindow(true);

--Set up settings
local MontecarloAccuracy_Phase2 = 1;
local MontecarloMinDistance_Phase2 = 0;
local MCPackerPhase2Border = 0;
local MontecarloPartRotation_Phase2 = 1; 
local MontecarloBorderspacez_Phase2 = 0;


local SLBorder = 0;
local SL_Accuracy = 0;
local SL_Voxelsize = 1;
local SL_Interlockprotection = 1;
local SL_RotationSteps = 3;
local SL_AllowFlip = 1;

local edit_MontecarloMinDistance_Phase2  = 0;
local edit_MontecarloBorderspacez_Phase2  = 0;
local edit_MCPackerPhase2Border  = 0;
local comboboxEfficeny_MC_Phase2  = 0;

local edit_SLBorder  = 0;
local combobox_Scaneline  = 0;
local combobox_SL_Voxelsize  = 0;
local combobox_SL_RotationSteps  = 0;
local checkbox_SL_Interlockprotection  = 0;
local checkbox_SL_AllowFlip  = 0;


local Package_BarWidth = 0.8; 
local Package_BarThickness = 1.2; 
local Package_PartSpacing = 1.2; 
local Package_GridSizeXY = 3.8; 
local Package_GridSizeZ = 2.4;

local edit_Package_BarWidth = 0;
local edit_Package_BarThickness = 0;
local edit_Package_PartSpacing = 0;
local edit_Package_GridSizeXY = 0;
local edit_Package_GridSizeZ = 0;


dialog_wf_model = nil;
dialog_wf_model_haschanged = true;
dialog_wf_model_iscancel = false;

package_text = nil;
package_dropdown = nil;
pack_selected = 0;
packagetray_dropdown = nil;
packagetray_selected = 0;

package_create_boxchecked = false; 

function local_mc_packtray(Actualtray) 
  local packer = Actualtray:createpacker(Actualtray.packingid_montecarlo);

  packer.borderspacingxy = MCPackerPhase2Border;
  packer.borderspacingz = MontecarloBorderspacez_Phase2;
  packer.packing_quality = MontecarloAccuracy_Phase2;
  packer.minimaldistance = tonumber(MontecarloMinDistance_Phase2);
  
  packer.z_limit  = 0.0;    -- If z_limit is set to zero, the default value, MachineSizeZ will be used
  packer.start_from_current_positions = false;
  ret = packer:pack();
  Actualtray:updatetodesktop();
  return ret;
end;
	
-- Scanline pack tray
function local_sl_packtray(Actualtray) 
  local packer = Actualtray:createpacker(Actualtray.packingid_3d);
  packer.allowrotationaxis = SL_AllowFlip;
  packer.coarsening = SL_Accuracy+1;
  packer.interlockingprotection = SL_Interlockprotection;
  packer.minimizeoutbox = true;
  packer.anglecount = SL_RotationSteps;
  packer.rastersize = SL_Voxelsize;
  packer.borderspacingxy = SLBorder;
  ret = packer:pack();
  Actualtray:updatetodesktop();
  return ret;
end;

function removetmptray ()
	local my_index = 0;
	for tray_index = 1, netfabbtrayhandler.traycount - 1 do
		local tray = netfabbtrayhandler:gettray(tray_index);
		if tray.name == "TMP_TRAY" then
			my_index = tray_index;
			break;
		end
	end;
	local ret = -1;
	if my_index ~= 0 then
		ret = netfabbtrayhandler:removetray(my_index);
	end;
	return ret;
end;

function model_pack_selected()
    local meshes = {};
	local selected_meshes = 0;
	local total_volume = 0;
	local total_ob_volume = 0;
	local calc_x = 0;
	local all_fits = false;
	local pack_result = 0;
	local number_of_packs = 0;
	
	local the_tray = netfabbtrayhandler:gettray(packagetray_selected);
    for mesh_index    = 0, the_tray.root.meshcount - 1 do
		local traymesh      = the_tray.root:getmesh(mesh_index);
		if traymesh.selected then
			table.insert(meshes, traymesh);
			selected_meshes = selected_meshes + 1;
			total_volume = total_volume + traymesh.volume;
			total_ob_volume = total_ob_volume + traymesh.outboxvolume;
			calc_x = math.pow(total_ob_volume,1/3);
		end;
    end;
	if selected_meshes == 0 then
		return 1;
	end;
	system:log("Selected meshes:" ..selected_meshes.. " Volume: " ..total_volume.. " Outbox Volume: " ..total_ob_volume.. " X: " ..calc_x);
	while not all_fits do
		local tmptray = netfabbtrayhandler:addtray("TMP_TRAY", calc_x,calc_x,calc_x);
		copy2tray(meshes, tmptray);
		if pack_selected == 0 then -- MC packer
			pack_result = local_mc_packtray(tmptray);
		else -- Scanline packer
			pack_result = local_sl_packtray(tmptray);	
		end;
		number_of_packs = number_of_packs + 1;
		if pack_result > 0 and pack_result < 4 then -- parts do no fit
			calc_x = calc_x + (calc_x / 10);
			removemeshesfromtray(tmptray);
			removetmptray();
		elseif pack_result == 0 then -- all packed
			local my_mesh = system:createmesh();
			for mesh_index    = 0, tmptray.root.meshcount - 1 do
				local traymesh      = tmptray.root:getmesh(mesh_index);
				newMesh = traymesh.mesh:dupe();
				local matrix   = traymesh.matrix; 
				newMesh:applymatrix(matrix);
				my_mesh:merge(newMesh);
			end;
			
			if package_create_boxchecked == false then	
				tray.root:addmesh(my_mesh);
				removemeshesfromtray(tmptray);
				removetmptray();
				all_fits = true;	
			else 
				if package_text.text ~= nil and package_text.text ~= "" then
					newname = package_text.text;
				else
					newname = "Cage with " ..selected_meshes.." mesh(es)";
				end;

				newcage = my_mesh:createmodelpackage(Package_BarWidth, Package_BarThickness, Package_PartSpacing, Package_GridSizeXY, Package_GridSizeZ, newname);
				my_mesh:merge(newcage);
			
				tray.root:addmesh(my_mesh, newname);
				removemeshesfromtray(tmptray);
				removetmptray();
				all_fits = true;
					
			end;
				
		else -- some serious error
			removemeshesfromtray(tmptray);
			removetmptray();
			system:log("Packing fatal error: "..pack_result);
			all_fits = true;
			return 2;
		end;
		if number_of_packs > 10 then
			return 3;
		end;
	end;
	return 0;
end;
function GetValuesFromGui () 
	MontecarloMinDistance_Phase2 = tonumber(edit_MontecarloMinDistance_Phase2.text);
	MontecarloBorderspacez_Phase2 = tonumber(edit_MontecarloBorderspacez_Phase2.text);
	MCPackerPhase2Border =  tonumber(edit_MCPackerPhase2Border.text);
	MontecarloAccuracy_Phase2 = comboboxEfficeny_MC_Phase2.selecteditem;
	MontecarloPartRotation_Phase2 = comboboxRotationConstraint_MC_Phase2.selecteditem;

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
	
	Package_BarWidth = tonumber(edit_Package_BarWidth.text); 
    Package_BarThickness = tonumber(edit_Package_BarThickness.text);
    Package_PartSpacing = tonumber(edit_Package_PartSpacing.text);
    Package_GridSizeXY = tonumber(edit_Package_GridSizeXY.text);
    Package_GridSizeZ = tonumber(edit_Package_GridSizeZ.text);
	
end;

function show_dialog_wf_model_ok ()
    GetValuesFromGui ();
	local ret = model_pack_selected();
	if ret ~= 0 then
		local message = "";
		local exit_state = false;
		if ret == 1 then
			message = "No selected models found in tray!";
		elseif ret == 2 then
			message = "Fatal packing error, exit";
			exit_state = true;
		elseif ret == 3 then
			message = "Too many iterations, exit";
			exit_state = true;
		else
			message = "Unknown error, exit";
			exit_state = true;
		end;
		system:messagedlg(message);
		dialog_wf_model:close (exit_state);
	end;
	removetmptray();
	application:triggerdesktopevent('updateparts') ;
	dialog_wf_model:close (true);
end;

function dialog_wf_model_pack_change ()
	pack_selected = package_dropdown.selecteditem;
	dialog_wf_model_haschanged = true;
	dialog_wf_model:close (false);
end;

function dialog_wf_model_pack2_change ()
	packagetray_selected = packagetray_dropdown.selecteditem;
	dialog_wf_model_haschanged = true;
	dialog_wf_model:close (false);
end;

function show_dialog_wf_model_oncancel ()
	dialog_wf_model_iscancel = true;
	dialog_wf_model:close (false);
end;

function show_dialog_wf_model ()
	local dialog, groupbox, label, dropdown, subbox1, edit, checkbox1, checkbox2, splitter, button, slider;
	local default_wide1 = 150;
	local d_w = 450;

	dialog = application:createdialog ();
	tabcontrol = dialog:addtabcontrol();
	 
	dialog.caption = "Subnest"
	dialog.width = d_w;
	dialog.translatecaption = false;
	dialog_wf_model = dialog;

    sheet = tabcontrol:addtabsheet();
    sheet.caption = "Main settings";
    sheet.translate = false;

    local groupboxExplanation =  sheet:addgroupbox ();
    groupboxExplanation.caption = "Explanation"
    groupboxExplanation.translate = false;
	  
	label = groupboxExplanation:addlabel ();
    label.caption = "Selected parts will be packed in sub area of the build room."
    label.translate = false;
	
    label = groupboxExplanation:addlabel ();
    label.caption = "The size of the packed area will be as small as possible. "
	label.translate = false;
  
	groupboxMainSettings =  sheet:addgroupbox ();
	groupboxMainSettings.caption = "Settings"
	groupboxMainSettings.borderstyle = 1;
	groupboxMainSettings.horizontalpadding = 10;
	groupboxMainSettings.verticalpadding = 10;
	groupboxMainSettings.translate = false;

	dropdown = groupboxMainSettings:adddropdown();
	dropdown.caption = "Select Tray: ";
	dropdown.captionwidth = default_wide1;
	dropdown.translatecaption = false;
		
	for tray_index = 0, netfabbtrayhandler.traycount - 1 do
		local model_tray = netfabbtrayhandler:gettray(tray_index);
		local model_tname = model_tray.name;
		if tray_index == 0 then
			model_tname = "Default Tray"
		end;
		dropdown:additem(model_tname,tray_index, 0, false);
	end;
	dropdown.selecteditem = packagetray_selected;
	dropdown.onchange = "dialog_wf_model_pack2_change";
		
	packagetray_dropdown = dropdown;
	
	dropdown = groupboxMainSettings:adddropdown();
	dropdown.caption = "Which Packer to use: ";
	dropdown.captionwidth = default_wide1;
	dropdown.translatecaption = false;
		
	dropdown:additem("MonteCarlo",0, 0, false);
	dropdown:additem("Scanline",1, 0, false);
	dropdown.selecteditem = pack_selected;
	dropdown.onchange = "dialog_wf_model_pack_change";
		
	package_dropdown = dropdown;
	
	checkbox1 = groupboxMainSettings:addcheckbox ();
	checkbox1.caption = "Create Package?";
	checkbox1.translate = false;
	checkbox1.onclick = "select_create_package_box";
	checkbox1.checked = package_create_boxchecked;
	
	package_checkbox = checkbox;
	
	checkbox2 = groupboxMainSettings:addcheckbox ();
	checkbox2.caption = "Merge Parts?";
	checkbox2.translate = false;
	
	package_checkbox = checkbox;
	
	edit = groupboxMainSettings:addedit ();
	edit.caption = "Name Package Cage:";
	edit.captionwidth = default_wide1;
	edit.text = "";
	edit.translate = false;
	edit.enabled = true;
	package_text = edit;
	
	splitter = dialog:addsplitter ();
	splitter:settoleft ();
	button = splitter:addbutton ();
	button.caption = "OK";
	button.translate = false;
	button.onclick = "show_dialog_wf_model_ok";

	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Cancel";
	button.translate = false;
	button.onclick = "show_dialog_wf_model_oncancel";


	--Packersetting
	sheet = tabcontrol:addtabsheet();
	sheet.caption = "Packer settings";
	sheet.translate = false;

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
  
    -- local Package_BarWidth = 0; 
    -- local Package_BarThickness = 0; 
    -- local Package_PartSpacing = 0; 
    -- local Package_GridSizeXY = 0; 
    -- local Package_GridSizeZ = 0;
  	--Packagesetting
	sheet = tabcontrol:addtabsheet();
	sheet.caption = "Package settings";
	sheet.translate = false;
	
	local groupboxPackageSetting =  sheet:addgroupbox ();	
	groupboxPackageSetting.caption = "Package settings"
	groupboxPackageSetting.translate = false;

	edit = groupboxPackageSetting:addedit ();
	edit.caption = "Bar Width";
	edit.captionwidth = 300;
	edit.translate = false;
	edit.text = tostring(Package_BarWidth);
	edit_Package_BarWidth = edit;

	edit = groupboxPackageSetting:addedit ();
	edit.caption = "Bar Thickness";
	edit.captionwidth = 300;
	edit.translate = false;
	edit.text = tostring(Package_BarThickness);
	edit_Package_BarThickness = edit;

	edit = groupboxPackageSetting:addedit ();
	edit.caption = "Part Spacing";
	edit.captionwidth = 300;
	edit.translate = false;
	edit.text = tostring(Package_PartSpacing);
	edit_Package_PartSpacing = edit;
	
	edit = groupboxPackageSetting:addedit ();
	edit.caption = "Grid Size XY";
	edit.captionwidth = 300;
	edit.translate = false;
	edit.text = tostring(Package_GridSizeXY);
	edit_Package_GridSizeXY = edit;

	edit = groupboxPackageSetting:addedit ();
	edit.caption = "GridSizeZ";
	edit.captionwidth = 300;
	edit.translate = false;
	edit.text = tostring(Package_GridSizeZ);
	edit_Package_GridSizeZ = edit;

	if dialog:show () then
        return true;
    end;
    return false;
end;	



function wf_modelpack ()
	system:setloggingtooglwindow(true);
	while dialog_wf_model_haschanged do
		if show_dialog_wf_model () then
			dialog_wf_model_haschanged = true;
			return;
		else
			if dialog_wf_model_iscancel then
				dialog_wf_model_iscancel = false;
				dialog_wf_model_haschanged = true;
				return;
			end;
		end;
	end;
end;

function select_create_package_box ()
	if  package_create_boxchecked == false then
		package_create_boxchecked = true;
	else
		package_create_boxchecked = false;
	end; 
end;

-- Model Package workflow END

wf_modelpack ();
