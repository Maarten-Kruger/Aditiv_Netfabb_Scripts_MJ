-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes only
--==============================================================================

-- This script is a component script to be included, it does not contain its own main routine

-- Start of Example 1 --------------------------------------------

function example_1 ()
	system:setloggingtooglwindow(true);
	if tray == nil then
		system:log('  tray is nil!');
	else
		-- Get root meshgroup from tray
		local root = tray.root;
		system:log('Tray with ' .. tostring(root.meshcount) .. ' meshes scaled and moved!');
		-- Iterate meshes in group
		for mesh_index    = 0, root.meshcount - 1 do
      
			local translate = 150;
			local scale     = 0.5;
			local mesh      = root:getmesh(mesh_index);
			local luamesh   = mesh.mesh;
     
			-- translate mesh
			mesh:translate(translate, 0, translate);
			mesh:scale(scale, scale, scale);
		end;  
	end;
  end;    

-- End of Example 1 ----------------------------------------------

-- Start of Example 5 ----------------------------------------------

function example_5()
	local newMesh;
	local repaired = 0;
	system:setloggingtooglwindow(true); 
	if tray == nil then
		system:log('  tray is nil!');
	else
		-- Get root meshgroup from tray
		local root = tray.root;

		-- Collect meshes in the tray
		local meshes = {};
		for mesh_index    = 0, root.meshcount - 1 do  
			local traymesh      = root:getmesh(mesh_index);
			table.insert(meshes, traymesh);
		end;
		-- Iterate over meshes in tray
		for i, traymesh in pairs(meshes) do   
			local luamesh   = traymesh.mesh;      
			if not luamesh.isok then
				newMesh = luamesh:dupe();
				local matrix = traymesh.matrix;   
				local oldname = traymesh.name;
				local newname = oldname.."_(repaired)";
				newMesh:repairsimple();     
				newMesh:applymatrix(matrix);
				root:removemesh(traymesh);
				root:addmesh(newMesh, newname);
				repaired = repaired + 1;
			end;  
		end;  
	end;
	if repaired > 0 then
		system:messagedlg(" " .. repaired .. " file(s) repaired!");
	end;
end;

-- End of Example 5 ----------------------------------------------

-- Start of Example 8 ----------------------------------------------

function example_8()
	local supp_counter = 0;
	if tray == nil then
		system:log('  tray is nil!');
	else
		local root = tray.root;
		-- Collect meshes in the tray
		local meshes = {};
		for mesh_index    = 0, root.meshcount - 1 do  
			local traymesh      = root:getmesh(mesh_index);
			table.insert(meshes, traymesh);
		end;
    
		-- Iterate meshes in group
		for i, traymesh in pairs(meshes) do   
			local luamesh   = traymesh.mesh;
			local matrix   = traymesh.matrix;
			newMesh = luamesh:dupe();      
			newMesh:applymatrix(matrix);
			support = newMesh:createsupport('Examples\\LUA Scripts\\dlp.support');
			traymesh:assignsupport(support, false);   
			supp_counter = supp_counter +1;
		end;  
	end;
	if supp_counter > 0 then
		system:messagedlg(" " .. supp_counter .. " file(s) supported!");
	end;

end;

-- End of Example 8 ----------------------------------------------



-- Start of Example 11 -------------------------------------------
-- The variable tray is predefined and corresponds to the current buildroom
-- Demonstrator for the new dialog functionality
-- Calculates prices for all parts in a tray

-- global vars for example 11

maindialog_11 = nil;
resultdialog_11 = nil;
edit_ConversionDownSkinToEuro_11 = nil;
edit_ConversionVolumeToEuro_11 = nil;

ConversionDownSkinToEuro_11 = 10;
ConversionVolumeToEuro_11 = 20;

price_11 = 0;
partname_11 = "";

function showmaindialog_11 ()

	local dialog, edit, combobox, splitter, button;

	dialog = application:createdialog ();
	dialog.caption = "Calculate Price"
	dialog.width = 400;
	dialog.translatecaption = false;
	maindialog_11 = dialog;

	edit = dialog:addedit ();
	edit.caption = "Working cost per hour for post processing: ";
	edit.captionwidth = 150;
	edit.text = "100 Euro";
	edit.translate = false;

	edit = dialog:addedit ();
	edit.caption = "Buildspeed: ";
	edit.captionwidth = 150;
	edit.translate = false;
	edit.text = "5 ccm/h";

	edit = dialog:addedit ();
	edit.caption = "Conversion Factor1:";
	edit.captionwidth = 150;
	edit.translate = false;
	edit.text = string.format ("%.3f", ConversionDownSkinToEuro_11);
    edit_ConversionDownSkinToEuro_11 = edit;

	edit = dialog:addedit ();
	edit.caption = "Conversion Factor2:";
	edit.captionwidth = 150;
	edit.translate = false;
	edit.text = string.format ("%.3f", ConversionVolumeToEuro_11);
    edit_ConversionVolumeToEuro_11 = edit;

	combobox = dialog:adddropdown ();
	combobox.caption = "Select option: ";
    combobox.customdraw = true; --needs to be enabled for color changes in dropdown
	combobox.captionwidth = 150;
    --combobox.backgroundcolor = '$AAAAAA';
    combobox.enabled = true;
	combobox.translate = false;

	combobox:additem ("Simple Part", 1, false, false, 0, "$FF0000");
	combobox:additem ("Average Part", 2, false, false, 0, "$00FF00");
	combobox:additem ("Difficult Part", 3, false, false, 0, "$0000FF"); 

    --Demo for making checkbox with colored font     
    --splitter = dialog:addsplitter ();
    --splitter:settoleft ();
    --label = splitter:addlabel ();
    --label.caption = "For checkbox";
    --label.fontcolor = "$00FF00";
    --label.translate = false;
    --splitter:settoright ();
    --checkbox = splitter:addcheckbox();
    
	splitter = dialog:addsplitter ();
	splitter:settoleft ();
	button = splitter:addbutton ();
	button.caption = "OK";
	button.translate = false;
	button.onclick = "maindialog_11_ok";
	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Cancel";
	button.translate = false;
	button.onclick = "maindialog_11_oncancel";

    
	if dialog:show () then
        ConversionDownSkinToEuro_11 = tonumber(edit_ConversionDownSkinToEuro_11.text);
        ConversionVolumeToEuro_11 = tonumber(edit_ConversionVolumeToEuro_11.text);
        return true;
    end;

    return false;

end;


function maindialog_11_ok ()
	maindialog_11:close (true);
end;

function maindialog_11_oncancel ()
	maindialog_11:close (false);
end;

function resultdialog_11_ok ()
	resultdialog_11:close (true);
end;

function resultdialog_11_oncancel ()
	resultdialog_11:close (false);
end;


function resultdialog_11_upload ()
        local url = string.format ("http://netfabb.com/newquote/name=%s&price=%.2f", partname_11, price_11);
        system:shellexecute (url);
end;

function showresultdialog_11 (mesh, analyzer, price_11)

	local dialog, edit, combobox, splitter, button;

	dialog = application:createdialog ();
	dialog.caption = "Price calculation"
	dialog.width = 600;
	dialog.translatecaption = false;
    resultdialog_11 = dialog;

	edit = dialog:addedit ();
	edit.caption = "Partname: ";
	edit.captionwidth = 150;
	edit.text = mesh.name;
	edit.readonly = true;
	edit.translate = false;

    partname_11 = mesh.name;

	outbox = mesh:calcoutbox ();


	edit = dialog:addedit ();
	edit.caption = "Size: ";
	edit.captionwidth = 150;
	edit.text = string.format ("%.3f x %.3f x %.3f mm", outbox.sizex, outbox.sizey, outbox.sizez);
	edit.readonly = true;
	edit.translate = false;

	edit = dialog:addedit ();
	edit.caption = "Volume: ";
	edit.captionwidth = 150;
	edit.text = string.format ("%.3f ccm", mesh.volume / 1000.0);
	edit.readonly = true;
	edit.translate = false;

	edit = dialog:addedit ();
	edit.caption = "Upskin area: ";
	edit.captionwidth = 150;
	edit.text = string.format ("%.3f qcm", analyzer.upskinarea / 100.0);
	edit.readonly = true;
	edit.translate = false;

	edit = dialog:addedit ();
	edit.caption = "Downskin area: ";
	edit.captionwidth = 150;
	edit.text = string.format ("%.3f qcm", analyzer.downskinarea / 100.0);
	edit.readonly = true;
	edit.translate = false;

	edit = dialog:addedit ();
	edit.caption = "Shadow area: ";
	edit.captionwidth = 150;
	edit.text = string.format ("%.3f qcm", analyzer.shadowarea / 100.0);
	edit.readonly = true;
	edit.translate = false;

	edit = dialog:addedit ();
	edit.caption = "Support volume: ";
	edit.captionwidth = 150;
	edit.text = string.format ("%.3f ccm", analyzer.supportvolume / 1000.0);
	edit.readonly = true;
	edit.translate = false;

	edit = dialog:addedit ();
	edit.caption = "Price: ";
	edit.captionwidth = 150;
	edit.text = string.format ("%.2f Euro", price_11);
	edit.readonly = true;
	edit.translate = false;
    edit.customcolor = 256 * 255;


	splitter2 = dialog:addsplitter ();
    splitter2:settoleft ();
	button = splitter2:addbutton ();
	button.caption = "Upload to server";
	button.translate = false;
	button.onclick = "resultdialog_11_upload";

    splitter2:settoright ();
	splitter = splitter2:addsplitter ();
	splitter:settoleft ();
	button = splitter:addbutton ();
	button.caption = "Next part";
	button.translate = false;
	button.onclick = "resultdialog_11_ok";
	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Cancel";
	button.translate = false;
	button.onclick = "resultdialog_11_oncancel";

    return dialog:show ();

end;

function analysepart_11 (mesh)
   local meshobject = mesh.mesh;
   local analyzer = meshobject:createanalyzer ();
   analyzer:createupskindownskinanalysis (45, 45, 10, true);
   analyzer:createshadowareaanalysis ();
   analyzer:createsupportvolumeanalysis (45);
   price_11 = analyzer.upskinarea / 1000 * ConversionDownSkinToEuro_11 + mesh.volume / 10000 * ConversionVolumeToEuro_11;
   return showresultdialog_11 (mesh, analyzer, price_11);
end;

function example_11 ()
	if showmaindialog_11 () then
		local root = tray.root;                                                        -- Iterate meshes in group
		for mesh_index    = 0, root.meshcount - 1 do
			local mesh    = root:getmesh(mesh_index);
			if not analysepart_11 (mesh) then
				return;
			end;
		end;
	else
		return;
	end;
end;

-- End of Example 11 -------------------------------------------
-- Start of Example 13 -------------------------------------------

function example_13 ()
	-- create ogl context
	gl_init (1024, 768);

	local outname = system:showsavedialog("png");
	if system:fileexists(outname) then
		system:messagedlg("Can't save: " .. outname .. " - file already exists!");
		return;
	end;

	if tray == nil then
		system:log('  tray is nil!');
	else
		-- Get root meshgroup from tray
		local root = tray.root;
		system:log('  tray with ' .. tostring(root.meshcount) .. ' meshes');
		-- Iterate meshes in group
		for mesh_index    = 0, root.meshcount - 1 do
			local traymesh      = root:getmesh(mesh_index);
			local luamesh   = traymesh.mesh;
 			-- make model out of mesh
			modelid = gl_createmodel (luamesh);
			-- set background
			gl_setbackgroundgradient(0, 0, 255, 0, 255, 0, 255, 0, 0, 0, 255, 255);
			-- add model to scene  
			glcontext:addmodeltoscene (modelid);
			-- set camera position
			gl_lookatmodel (modelid, 0, -1, 0, 0, 0, 1, 0.55);
			-- save preview image  
			gl_exportimage (outname, IMAGETYPE_PNG, 90); 
		end;  
		system:shellexecute(outname, "",false, true);
	end;
end;

-- End of Example 13 ---------------------------------------------
-- Start of Example 17 -------------------------------------------

function example_17 ()
	local labelled = 0;
	if tray == nil then
		system:log('  tray is nil!');
	else
		local root = tray.root; 
		-- Collect meshes in the tray
		local meshes = {};
		for mesh_index    = 0, root.meshcount - 1 do  
			local traymesh      = root:getmesh(mesh_index);
			table.insert(meshes, traymesh);
		end;
		-- Iterate meshes in group
		local stamper = system:createstamper();
		stamper.depth = 2;
		stamper.height = 20;
		stamper.issubtracted = true;
      
		for i, traymesh in pairs(meshes) do  
			local luamesh   = traymesh.mesh;
			stamper:setpos(0,50,50);
			stamper:setnormal(-1,0,0);
			stamper:setupvector(0,0,-1);
			local newmesh = stamper:stamp(luamesh, "Netfabb-" .. i .. " ");
			root:addmesh(newmesh,traymesh.name.. "_(labelled)");
			labelled = labelled + 1;
		end;  
	end; 
	if labelled > 0 then
		system:messagedlg(" " .. labelled .. " file(s) labelled!");
	end;

end;

-- End of Example 17 ---------------------------------------------
-- Start of Example 18 -------------------------------------------

function GenerateOffsetOfmesh(meshPar, offset)
  local luamesh   = meshPar.mesh;
  local matrix   = meshPar.matrix;
  luamesh:applymatrix(matrix);
  local newmesh = luamesh:offset(offset,offset / 3.0, true, false);
  return newmesh;
end;

function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function example_18 ()
	local volumeThreshold = 1000;
	local OffsetLarge = 5;
	local OffsetSmall = 0.5;
	
	system:setloggingtooglwindow(true);

	if tray == nil then
		system:log('  tray is nil!');
	else
		local root = tray.root;
		local meshesPre = {};
		local meshesOrig = {};
		local meshesOffset = {};
		local matrixOrig = {};
		local OffsetCorr = {};
		local meshesOffset = {};
		
		for mesh_index    = 0, root.meshcount - 1 do
			local traymesh = root:getmesh(mesh_index);
			table.insert(meshesPre, traymesh);
		end;

		system:log('meshesPre '..tablelength(meshesPre));
		for i, traymesh in pairs(meshesPre) do
			local luamesh = traymesh.mesh;
			local matrix = traymesh.matrix;
			luamesh:applymatrix(matrix);
			--root:removemesh(traymesh);
			table.insert(meshesOrig, root:addmesh(luamesh));
		end;

		for i, traymesh in pairs(meshesPre) do
			root:removemesh(traymesh);
		end;

		system:log('Generate Offset');
		for i, traymesh in pairs(meshesOrig) do
			if (getVolumeOfmesh(traymesh) > volumeThreshold) then
				local newmesh = GenerateOffsetOfmesh(traymesh, OffsetLarge);
				local newtraymesh = root:addmesh(newmesh);
				newtraymesh:setpackingoption('restriction', 'norestriction');
				table.insert(meshesOffset, newtraymesh);
				table.insert(OffsetCorr, OffsetLarge);
				system:log('large');
			else
				local newmesh = GenerateOffsetOfmesh(traymesh, OffsetSmall);
				local newtraymesh = root:addmesh(newmesh);
				newtraymesh:setpackingoption('restriction', 'norestriction');
				table.insert(meshesOffset, newtraymesh);
				table.insert(OffsetCorr, OffsetSmall);
				system:log('small');
			end;
		end;

		system:log('Move Old meshes from the buildplatform');
		for i, traymesh in pairs(meshesOrig) do
			local matrix = traymesh.matrix;
			MoveMatrixZ(matrix, 1000);
			traymesh:setmatrix(matrix);
			traymesh:setpackingoption('restriction', 'locked');
		end;

		system:log('Pack');
		local packer = tray:createpacker(tray.packingid_montecarlo);
		-- Please note that the createpacker command creates a snapeshoot of the
		-- tray with its current parts. If parts are removed or added afterwards 
		-- you need to create a new packer
		packer.packing_quality = -1;
		packer.z_limit  = 0.0;
		packer.start_from_current_positions = false;
		packer:pack();

		system:log('Move orig parts to places');
		for i, traymesh in pairs(meshesOrig) do
			local packedMesh = meshesOffset[i];
			traymesh:setmatrix(packedMesh.matrix);
			local offset = OffsetCorr[i];
		end;

		system:log('remove offset parts');
		for i, traymesh in pairs(meshesOffset) do
			local Mesh = meshesOffset[i];
			--root:removemesh(Mesh); 
		end;
	end;
end;

-- End of Example 18 ---------------------------------------------
-- Start of Example 19 -------------------------------------------

function example_19()
	system:setloggingtooglwindow(true);

	local pa_id = tray.packingid_montecarlo;
	local packer = tray:createpacker(pa_id);
	local outboxOrig = packer:getoutbox();
	local outbox = packer:getoutbox();
	local tempMaxX = outbox.maxx;
	local tempMaxY = outbox.maxy;

	outbox.minx = 100; --For the first packing we reduce the packer area
	outbox.miny = 100;
	outbox.maxx = tempMaxX - 100;
	outbox.maxy = tempMaxY - 100;
	packer:setoutbox(outbox);
	volumeThreshold = 10000; --Cubic mm, the volume threshold, everything higher is considered as large and is packed in the center

	if pa_id == tray.packingid_montecarlo then
		-- Setting options in the Monte Carlo packer
		packer.packing_quality = -1;
		packer.z_limit  = 0.0;    -- If z_limit is set to zero, the default value, MachineSizeZ will be used
		packer.start_from_current_positions = false; 
	end;
	if tray == nil then
		system:log('  tray is nil!');
	else
		local root = tray.root;
		local meshesOrig = {};
		for mesh_index    = 0, root.meshcount - 1 do
			local traymesh = root:getmesh(mesh_index);
			table.insert(meshesOrig, traymesh);
		end;
		--All meshes above the buildplatform
		system:log('Move Old meshes from the buildplatform');
		for i, traymesh in pairs(meshesOrig) do
			local matrix = traymesh.matrix;
			MoveMatrixZ(matrix, 1000);
			traymesh:setmatrix(matrix);
		end;
		for i, traymesh in pairs(meshesOrig) do
			if (getVolumeOfmesh(traymesh) > volumeThreshold) then
				traymesh:setpackingoption('restriction', 'norestriction');
			else
				traymesh:setpackingoption('restriction', 'locked');
			end;
		end;
		--Pack large things
		local errorcode=packer:pack();
		--Now pack small things
		packer:setoutbox(outboxOrig);
		for i, traymesh in pairs(meshesOrig) do
			if (getVolumeOfmesh(traymesh) < volumeThreshold) then
				traymesh:setpackingoption('restriction', 'norestriction');
			else
				traymesh:setpackingoption('restriction', 'locked');
			end;
		end;
		local errorcode=packer:pack();
		checkErrorCodeMCpacker(errorcode);
	end;
end;
-- End of Example 19 ---------------------------------------------

-- Start of Example 20 -------------------------------------------
function example_20 ()
  local AConfigFile = application:getappdatadirectory() .. "/netfabb/screenshot.xml"

  GScreenshotDialog = application:createdialog()
  GScreenshotDialog.caption = "Configure Screenshot"
  GScreenshotDialog.translatecaption = false

  local ASavedEdits = { }
  local ASavedCheck = { }
  local AOptions = { }

  local ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Texture"
  ACheckbox.checked = true
  
  ASavedCheck["texture"] = ACheckbox
  AOptions["show_textures"] = ACheckbox

  ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Colors"
  ACheckbox.checked = true

  ASavedCheck["colors"] = ACheckbox
  AOptions["show_colors"] = ACheckbox

  ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Show Ruler Horizontal"
  ACheckbox.checked = true

  ASavedCheck["hruler"] = ACheckbox
  AOptions["show_horizontalruler"] = ACheckbox

  ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Show Ruler Vertical"
  ACheckbox.checked = true

  ASavedCheck["vruler"] = ACheckbox
  AOptions["show_verticalruler"] = ACheckbox

  ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Show Labels"
  ACheckbox.checked = true

  ASavedCheck["labels"] = ACheckbox
  AOptions["show_labels"] = ACheckbox

  ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Show Viewcube"
  ACheckbox.checked = true

  ASavedCheck["viewcube"] = ACheckbox
  AOptions["show_viewcube"] = ACheckbox

  ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Show Platform"
  ACheckbox.checked = true

  ASavedCheck["platform"] = ACheckbox
  AOptions["show_platform"] = ACheckbox

  ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Show Coordinate System"
  ACheckbox.checked = true

  ASavedCheck["coordinate"] = ACheckbox
  AOptions["show_coordsystem"] = ACheckbox

  ACheckbox = GScreenshotDialog:addcheckbox()
  ACheckbox.translate = false
  ACheckbox.caption = "Show Platform"
  ACheckbox.checked = true

  ASavedCheck["platform"] = ACheckbox
  AOptions["show_platform"] = ACheckbox

  local AWidth = GScreenshotDialog:addedit()
  AWidth.caption = "Screenshot Width:"
  AWidth.translate = false
  AWidth.captionwidth = 120
  AWidth.text = 1920
  
  ASavedEdits["width"] = AWidth

  local AHeight = GScreenshotDialog:addedit()
  AHeight.caption = "Screenshot Height:"
  AHeight.translate = false
  AHeight.captionwidth = 120
  AHeight.text = 1080
  
  ASavedEdits["height"] = AHeight

  local AGroupbox = GScreenshotDialog:addgroupbox()
  AGroupbox.caption = "Camera Data"
  AGroupbox.translate = false

  ACamera = AGroupbox:addcheckbox()
  ACamera.translate = false
  ACamera.caption = "Configure Camera"
  ACamera.checked = false
  ACamera.onclick = "screenshot_camera"

  ASavedCheck["camera"] = ACamera
  ACamData = { }

  local ATopSplit = AGroupbox:addsplitter()
  ATopSplit:settoleft()

  local ASplit1 = ATopSplit:addsplitter()
  ASplit1:settoleft()

  local ALabel = ASplit1:addlabel()
  ALabel.caption = "Eye"
  ALabel.translate = false

  ACamData["eye"] = { }

  ASplit1:settoright()
  local AEdit = ASplit1:addedit()
  AEdit.caption = "X"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "1"

  ACamData["eye"]["x"] = AEdit
  ASavedEdits["eyex"] = AEdit

  ATopSplit:settoright()
  ASplit1 = ATopSplit:addsplitter()
  ASplit1:settoleft()

  local AEdit = ASplit1:addedit()
  AEdit.caption = "Y"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "0"
  
  ACamData["eye"]["y"] = AEdit
  ASavedEdits["eyey"] = AEdit

  ASplit1:settoright()
  local AEdit = ASplit1:addedit()
  AEdit.caption = "Z"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "0"

  ACamData["eye"]["z"] = AEdit
  ASavedEdits["eyez"] = AEdit

  ATopSplit = AGroupbox:addsplitter()
  ATopSplit:settoleft()

  ASplit1 = ATopSplit:addsplitter()
  ASplit1:settoleft()

  ALabel = ASplit1:addlabel()
  ALabel.caption = "Up-Vector"
  ALabel.translate = false

  ACamData["up"] = { }

  ASplit1:settoright()
  local AEdit = ASplit1:addedit()
  AEdit.caption = "X"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "0"

  ACamData["up"]["x"] = AEdit
  ASavedEdits["upx"] = AEdit

  ATopSplit:settoright()
  ASplit1 = ATopSplit:addsplitter()
  ASplit1:settoleft()

  local AEdit = ASplit1:addedit()
  AEdit.caption = "Y"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "0"

  ACamData["up"]["y"] = AEdit
  ASavedEdits["upy"] = AEdit

  ASplit1:settoright()
  local AEdit = ASplit1:addedit()
  AEdit.caption = "Z"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "1"

  ACamData["up"]["z"] = AEdit
  ASavedEdits["upz"] = AEdit

  ATopSplit = AGroupbox:addsplitter()
  ATopSplit:settoleft()

  ASplit1 = ATopSplit:addsplitter()
  ASplit1:settoleft()

  ALabel = ASplit1:addlabel()
  ALabel.caption = "Center"
  ALabel.translate = false

  ACamData["center"] = { }

  ASplit1:settoright()
  local AEdit = ASplit1:addedit()
  AEdit.caption = "X"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "0"

  ACamData["center"]["x"] = AEdit
  ASavedEdits["centerx"] = AEdit

  ATopSplit:settoright()
  ASplit1 = ATopSplit:addsplitter()
  ASplit1:settoleft()

  local AEdit = ASplit1:addedit()
  AEdit.caption = "Y"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "0"

  ACamData["center"]["y"] = AEdit
  ASavedEdits["centery"] = AEdit

  ASplit1:settoright()
  local AEdit = ASplit1:addedit()
  AEdit.caption = "Z"
  AEdit.captionwidth = 25
  AEdit.translate = false
  AEdit.text = "0"

  ACamData["center"]["z"] = AEdit
  ASavedEdits["centerz"] = AEdit

  AZoom = AGroupbox:addedit()
  AZoom.caption = "Zoom Factor:"
  AZoom.captionwidth = 120
  AZoom.translate = false
  AZoom.text = "1"
  
  ASavedEdits["zoom"] = AZoom
  
  AGroupbox = GScreenshotDialog:addgroupbox()
  AGroupbox.caption = "Circle animation"
  AGroupbox.translate = false
  
  GScreenshotCircleAnimation = AGroupbox:addcheckbox()
  GScreenshotCircleAnimation.caption = "Render circle animation"
  GScreenshotCircleAnimation.translate = false
  GScreenshotCircleAnimation.onclick = "CircleAnimationClick"
  
  ASavedCheck["circle"] = GScreenshotCircleAnimation
  
  GScreenshotCircleFrames = AGroupbox:addedit()
  GScreenshotCircleFrames.caption = "Number of frames:"
  GScreenshotCircleFrames.captionwidth = 120
  GScreenshotCircleFrames.translate = false
  GScreenshotCircleFrames.text = "120"
  GScreenshotCircleFrames.enabled = false
  
  ASavedEdits["frames"] = GScreenshotCircleFrames
  
  GScreenshotCircleDistance = AGroupbox:addedit()
  GScreenshotCircleDistance.caption = "Distance:"
  GScreenshotCircleDistance.captionwidth = 120
  GScreenshotCircleDistance.translate = false
  GScreenshotCircleDistance.text = "5"
  GScreenshotCircleDistance.enabled = false
  
  ASavedEdits["distance"] = GScreenshotCircleDistance
  
  GScreenshotCircleHeight = AGroupbox:addedit()
  GScreenshotCircleHeight.caption = "Height:"
  GScreenshotCircleHeight.captionwidth = 120
  GScreenshotCircleHeight.translate = false
  GScreenshotCircleHeight.text = "5"
  GScreenshotCircleHeight.enabled = false
  
  ASavedEdits["circleheight"] = GScreenshotCircleHeight
  
  ASplit1 = AGroupbox:addsplitter()
  ASplit1.width = 80
  ASplit1:settoleft()
  
  GScreenshotCircleFolder = ASplit1:addedit()
  GScreenshotCircleFolder.caption = "Folder:"
  GScreenshotCircleFolder.captionwidth = 60
  GScreenshotCircleFolder.translate = false
  GScreenshotCircleFolder.enabled = false
  
  ASavedEdits["circlefolder"] = GScreenshotCircleFolder
  
  ASplit1:settoright()
  
  GScreenshotCircleFolderBtn = ASplit1:addbutton()
  GScreenshotCircleFolderBtn.caption = "..."
  GScreenshotCircleFolderBtn.translate = false
  GScreenshotCircleFolderBtn.onclick = "CircleAnimationChooseFolder"
  GScreenshotCircleFolderBtn.enabled = false
  

  ASplit1 = AGroupbox:addsplitter()
  ASplit1:settoleft()

  AButton = ASplit1:addbutton()
  AButton.caption = "GENERAL_OK"
  AButton.onclick = "screenshot_ok"

  ASplit1:settoright()

  local AButton = ASplit1:addbutton()
  AButton.caption = "GENERAL_CANCEL"
  AButton.onclick = "screenshot_cancel"

  screenshot_camera()

  if system:fileexists(AConfigFile) then
    local AConfig = system:loadxml(AConfigFile)
    
    for k,v in pairs(ASavedEdits) do
      local ANode = AConfig:findchild(k)
      
      if ANode ~= nil then
        v.text = ANode.value
      end
    end
    
    for k,v in pairs(ASavedCheck) do
      local ANode = AConfig:findchild(k)
      
      if ANode ~= nil then
        if ANode.value == "1" then 
          v.checked = true 
        else
          v.checked = false
        end
      end
    end
    
    CircleAnimationClick()
    screenshot_camera()
  end
  
  if GScreenshotDialog:show() then
    AConfig = system:createxml()
    
    for k,v in pairs(ASavedEdits) do
      AConfig:addchild(k).value = v.text
    end
    
    for k,v in pairs(ASavedCheck) do
      if v.checked then
        AConfig:addchild(k).value = "1"
      else
        AConfig:addchild(k).value = "0"
      end
    end
    
    AConfig:savetofile(AConfigFile)
  
    local AAnimate = GScreenshotCircleAnimation.checked
    
    local AFile = ""
    
    if AAnimate then
      AFile = GScreenshotCircleFolder.text
    else
      AFile = system:showsavedialog("png")
    end
    
    if AFile ~= nil then
      if AAnimate then
        local ACount = tonumber(GScreenshotCircleFrames.text)
        
        for AFrame = 0, ACount - 1 do
          local AX = tonumber(GScreenshotCircleDistance.text) * math.cos((AFrame * 360.0 / ACount) * math.pi / 180.0) + tonumber(ACamData["center"]["x"].text)
          local AY = tonumber(GScreenshotCircleDistance.text) * math.sin((AFrame * 360.0 / ACount) * math.pi / 180.0) + tonumber(ACamData["center"]["y"].text)
          
          ACamData["eye"]["x"].text = AX
          ACamData["eye"]["y"].text = AY
          ACamData["eye"]["z"].text = tonumber(GScreenshotCircleHeight.text) + tonumber(ACamData["center"]["z"].text)
          
          local AJson = system:createjson()
          AJson:loadfromstring(CreateJsonString(AOptions, true, AZoom, ACamData))
          
          local ASNum = tostring(AFrame)
          
          while string.len(ASNum) < 4 do
            ASNum = "0" .. ASNum
          end
          
          AJson:savetofile(GScreenshotCircleFolder.text .. "/json_" .. ASNum .. ".json");
          
          local AImage = system:createscreenshot(tonumber(AWidth.text), tonumber(AHeight.text), AJson)
          AImage:saveto(GScreenshotCircleFolder.text .. "/frame_" .. ASNum .. ".png")
        end
      else
        local AJson = system:createjson()
        AJson:loadfromstring(CreateJsonString(AOptions, ACamData.checked, AZoom, ACamData))

        local AImage = system:createscreenshot(tonumber(AWidth.text), tonumber(AHeight.text), AJson)
        AImage:saveto(AFile)
      end
    end
  end
end;

function CreateJsonString(AOptions, ACamera, AZoom, ACamData)
  local s = "{\n"
  for k, v in pairs(AOptions) do
    if s ~= "{\n" then s = s .. ",\n" end
    s = s .. "  \"" .. k .. "\": " .. tostring(v.checked)
  end

  if ACamera then
    s = s .. ",\n  \"camera\": {\n    \"zoom\": " .. AZoom.text .. ",\n"

    local ANum = 0
    for k, v in pairs(ACamData) do
      if ANum ~= 0 then s = s .. ",\n" end
      ANum = ANum + 1
      s = s .. "    \"" .. k .. "\": ["

      local ACnt = 0
      for k2, v2 in pairs(v) do
        if ACnt ~= 0 then s = s .. ", " end
        s = s .. v2.text
        ACnt = ACnt + 1
      end

      s = s .. "]"
    end

    s = s .. "  }"
  end

  s = s .. "\n}"
  
  return s
end

function screenshot_ok()
  GScreenshotDialog:close(true)
end

function screenshot_cancel()
  GScreenshotDialog:close(false)
end

function screenshot_camera()
  for k,v in pairs(ACamData) do
    for k2, v2 in pairs(v) do
      v2.enabled = ACamera.checked
    end
  end

  AZoom.enabled = ACamera.checked
end

function CircleAnimationClick()
  GScreenshotCircleDistance .enabled = GScreenshotCircleAnimation.checked
  GScreenshotCircleHeight   .enabled = GScreenshotCircleAnimation.checked
  GScreenshotCircleFrames   .enabled = GScreenshotCircleAnimation.checked
  GScreenshotCircleFolderBtn.enabled = GScreenshotCircleAnimation.checked
  GScreenshotCircleFolder   .enabled = GScreenshotCircleAnimation.checked
  
  ACamera.checked = ACamera.checked or GScreenshotCircleAnimation.checked
  ACamera.enabled = not GScreenshotCircleAnimation.checked
  
  screenshot_camera()
end

function CircleAnimationChooseFolder()
  local AFolder = system:showdirectoryselectdialog(true, true, true)
  
  if AFolder ~= "" then
    GScreenshotCircleFolder.text = AFolder
  end
end
-- End of Example 20 ---------------------------------------------
