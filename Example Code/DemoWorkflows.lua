
-- LUA Script for Autodesk Netfabb (2019.1)
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes only
--==============================================================================

-- This script is for the LUA Automation module in the main module

system:executescriptfile ("Examples\\\\LUA Scripts\\\\BaseRoutines.lua");
system:executescriptfile ("Examples\\\\LUA Scripts\\\\Workflows.lua");

maindialog = nil;

function showmaindialog ()

	local totalwidth = 1200;
	local buttonwidth = 120;
	local splitterwidth = 140;

	local dialog, groupbox, label, splitter, splitter1, splitter2, splitter3, splitter4, splitter5, splitter6, button;

	dialog = application:createdialog ();
	dialog.caption = "Demo Workflows"
	dialog.width = totalwidth;
	dialog.translatecaption = false;
	maindialog = dialog;

	-- General section --------------------------------------------------------
	local g1, s1, s2, s3, s4, s5, s6, s7, s8, s9, b1, l1;
	
	g1 =  dialog:addgroupbox ();
	g1.caption = "General"
	g1.borderstyle = 1;
	g1.horizontalpadding = 10;
	g1.verticalpadding = 10;
	g1.translate = false;
	
	s1 = g1:addsplitter ();
	s1.splittype = 1;
	s1.width = totalwidth / 2;
	s1:settoleft ();

	s2 = s1:addsplitter ();
	s2.splittype = 1;
	s2.width = splitterwidth;
	s2:settoleft ();
	
	s1:settoright ();
	
	s3 = s1:addsplitter ();
	s3.splittype = 1;
	s3.width = splitterwidth;
	s3:settoleft ();
	
	b1 = s2:addbutton ();
	b1.caption = "Load part";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "load_part";

	s2:settoright ();	
	l1 = s2:addlabel ();
	l1.caption = "Loads a part (Mesh or CAD Model) into the build room";
	l1.translate = false;
	
	s3:settoleft ();	
	b1 = s3:addbutton ();
	b1.caption = "Load directory";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "load_dir";

	s3:settoright ();	
	l1 = s3:addlabel ();
	l1.caption = "Loads a complete directory into the build room";
	l1.translate = false;
	
	s1:settoleft ();
	
	s4 = s1:addsplitter ();
	s4.splittype = 1;
	s4.width = splitterwidth;
	s4:settoleft ();
	
	s1:settoright ();
	
	s5 = s1:addsplitter ();
	s5.splittype = 1;
	s5.width = splitterwidth;
	s5:settoleft ();
--[[	
	b1 = s4:addbutton ();
	b1.caption = "Load fabbproject";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "load_fabb";

	s4:settoright ();	
	l1 = s4:addlabel ();
	l1.caption = "Loads a fabbproject (removes current one)";
	l1.translate = false;
--]]	
	s5:settoleft ();	
	b1 = s5:addbutton ();
	b1.caption = "Save as fabbproject";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "save_fabb";

	s5:settoright ();	
	l1 = s5:addlabel ();
	l1.caption = "Saves the content of the application as a fabbproject";
	l1.translate = false;
	
	
	s1:settoleft ();
	
	s6 = s1:addsplitter ();
	s6.splittype = 1;
	s6.width = splitterwidth;
	s6:settoleft ();
	
	s1:settoright ();
	
	s7 = s1:addsplitter ();
	s7.splittype = 1;
	s7.width = splitterwidth;
	s7:settoleft ();
	
	b1 = s6:addbutton ();
	b1.caption = "Empty Trays";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "empty_trays";

	s6:settoright ();	
	l1 = s6:addlabel ();
	l1.caption = "Empties the content of all trays";
	l1.translate = false;
	
	s7:settoleft ();	
	b1 = s7:addbutton ();
	b1.caption = "Create Tray";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "create_tray";

	s7:settoright ();	
	l1 = s7:addlabel ();
	l1.caption = "Creates a new tray with custom size";
	l1.translate = false;

	-- Workflow section ---------------------------------------------------------------------------	
	g1 =  dialog:addgroupbox ();
	g1.caption = "Workflows"
	g1.borderstyle = 1;
	g1.horizontalpadding = 10;
	g1.verticalpadding = 10;
	g1.translate = false;
	
	s1 = g1:addsplitter ();
	s1.splittype = 1;
	s1.width = totalwidth / 2;
	s1:settoleft ();

	s2 = s1:addsplitter ();
	s2.splittype = 1;
	s2.width = splitterwidth;
	s2:settoleft ();
	
	s1:settoright ();
	
	s3 = s1:addsplitter ();
	s3.splittype = 1;
	s3.width = splitterwidth;
	s3:settoleft ();
	
	b1 = s2:addbutton ();
	b1.caption = "Scale && Rename";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "wf_scale";

	s2:settoright ();	
	l1 = s2:addlabel ();
	l1.caption = "Scales all models and renames them accordingly";
	l1.translate = false;
	
	s3:settoleft ();	
	b1 = s3:addbutton ();
	b1.caption = "3-Tray Packing";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "wf_pack";

	s3:settoright ();	
	l1 = s3:addlabel ();
	l1.caption = "Packs all parts over a maximum of 3 trays, returns log as XML";
	l1.translate = false;

	s1 = g1:addsplitter ();
	s1.splittype = 1;
	s1.width = totalwidth / 2;
	s1:settoleft ();

	s2 = s1:addsplitter ();
	s2.splittype = 1;
	s2.width = splitterwidth;
	s2:settoleft ();
	
	s1:settoright ();
	
	s3 = s1:addsplitter ();
	s3.splittype = 1;
	s3.width = splitterwidth;
	s3:settoleft ();
	
	b1 = s2:addbutton ();
	b1.caption = "Lane Packing";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "wf_lane";

	s2:settoright ();	
	l1 = s2:addlabel ();
	l1.caption = "Optimize parts by height, define lanes and 2D pack a tray lane by lane";
	l1.translate = false;

	s3:settoleft ();	
	b1 = s3:addbutton ();
	b1.caption = "Model Package";
	b1.width = buttonwidth;
	b1.translate = false;
	b1.onclick = "wf_modelpack";

	s3:settoright ();	
	l1 = s3:addlabel ();
	l1.caption = "Packs all selected parts, creates a model package around them and merges all";
	l1.translate = false;
-- last buttons	

	splitter = dialog:addsplitter ();
	splitter:settoleft ();
	button = splitter:addbutton ();
	button.caption = "Refresh";
	button.translate = false;
	button.onclick = "maindialog_refresh";
	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Close";
	button.translate = false;
	button.onclick = "maindialog_onclose";
    
	if dialog:show () then
        return true;
    end;
    return false;
end;

function maindialog_refresh ()
	maindialog:close (true);
end;

function maindialog_onclose ()
	maindialog:close (false);
end;

-- Main
while showmaindialog () do

end;


