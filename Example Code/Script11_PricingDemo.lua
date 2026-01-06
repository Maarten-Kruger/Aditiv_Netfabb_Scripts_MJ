-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes only
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Demonstrator for the new dialog functionality
-- Calculates prices for all parts in a tray

maindialog = nil;
resultdialog = nil;
edit_ConversionDownSkinToEuro = nil;
edit_ConversionVolumeToEuro = nil;

ConversionDownSkinToEuro = 10;
ConversionVolumeToEuro = 20;

price = 0;
partname = "";

function showmaindialog ()

	local dialog, edit, combobox, splitter, button;

	dialog = application:createdialog ();
	dialog.caption = "Calculate Price"
	dialog.width = 400;
	dialog.translatecaption = false;
	maindialog = dialog;

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
	edit.text = string.format ("%.3f", ConversionDownSkinToEuro);
    edit_ConversionDownSkinToEuro = edit;

	edit = dialog:addedit ();
	edit.caption = "Conversion Factor2:";
	edit.captionwidth = 150;
	edit.translate = false;
	edit.text = string.format ("%.3f", ConversionVolumeToEuro);
    edit_ConversionVolumeToEuro = edit;

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
	button.onclick = "maindialog_ok";
	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Cancel";
	button.translate = false;
	button.onclick = "maindialog_oncancel";

    
	if dialog:show () then
        ConversionDownSkinToEuro = tonumber(edit_ConversionDownSkinToEuro.text);
        ConversionVolumeToEuro = tonumber(edit_ConversionVolumeToEuro.text);
        return true;
    end;

    return false;

end;


function maindialog_ok ()
	maindialog:close (true);
end;

function maindialog_oncancel ()
	maindialog:close (false);
end;

function resultdialog_ok ()
	resultdialog:close (true);
end;

function resultdialog_oncancel ()
	resultdialog:close (false);
end;


function resultdialog_upload ()
        url = string.format ("http://netfabb.com/newquote/name=%s&price=%.2f", partname, price);
        system:shellexecute (url);
end;

function showresultdialog (mesh, analyzer, price)

	local dialog, edit, combobox, splitter, button;

	dialog = application:createdialog ();
	dialog.caption = "Price calculation"
	dialog.width = 600;
	dialog.translatecaption = false;
    resultdialog = dialog;

	edit = dialog:addedit ();
	edit.caption = "Partname: ";
	edit.captionwidth = 150;
	edit.text = mesh.name;
	edit.readonly = true;
	edit.translate = false;

    partname = mesh.name;

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
	edit.text = string.format ("%.2f Euro", price);
	edit.readonly = true;
	edit.translate = false;
    edit.customcolor = 256 * 255;


	splitter2 = dialog:addsplitter ();
    splitter2:settoleft ();
	button = splitter2:addbutton ();
	button.caption = "Upload to server";
	button.translate = false;
	button.onclick = "resultdialog_upload";

    splitter2:settoright ();
	splitter = splitter2:addsplitter ();
	splitter:settoleft ();
	button = splitter:addbutton ();
	button.caption = "Next part";
	button.translate = false;
	button.onclick = "resultdialog_ok";
	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Cancel";
	button.translate = false;
	button.onclick = "resultdialog_oncancel";

    return dialog:show ();

end;

function analysepart (mesh)
   local meshobject = mesh.mesh;
   local analyzer = meshobject:createanalyzer ();
   analyzer:createupskindownskinanalysis (45, 45, 10, true);
   analyzer:createshadowareaanalysis ();
   analyzer:createsupportvolumeanalysis (45);
   price = analyzer.upskinarea / 1000 * ConversionDownSkinToEuro + mesh.volume / 10000 * ConversionVolumeToEuro;
   return showresultdialog (mesh, analyzer, price);
end;

if showmaindialog () then

  local root = tray.root;                                                        -- Iterate meshes in group
  for mesh_index    = 0, root.meshcount - 1 do
    local mesh      = root:getmesh(mesh_index);
	if not analysepart (mesh) then
		return;
	end;
  end;
else
  return;
end;


