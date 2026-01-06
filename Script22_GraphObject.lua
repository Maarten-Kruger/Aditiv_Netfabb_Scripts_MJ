-- LUA Script for Autodesk Netfabb 2020.1
-- Copyright by Autodesk 2019
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- basic graph object usage example

dialog_wf_graph = nil;
dialog_wf_graph_haschanged = true;
dialog_wf_graph_iscancel = false;
wf_graph_col = nil;
number_of_col = 2;
wf_graph_row = nil;
number_of_row = 10;
wf_graph_h = nil;
number_height = 128;
wf_graph_w = nil;
number_width = 128;
filename = nil;

function show_dialog_wf_graph ()
	local dialog, groupbox, subbox1, edit, checkbox, splitter, button, mygraph, image;

	dialog = application:createdialog ();
	dialog.caption = "Graph Test"
	dialog.width = 300;
	dialog.translatecaption = false;
	dialog_wf_graph = dialog;
	
	groupbox =  dialog:addgroupbox ();
	groupbox.caption = "Graph Settings"
	groupbox.borderstyle = 1;
	groupbox.horizontalpadding = 10;
	groupbox.verticalpadding = 10;
	groupbox.translate = false;
	
	edit = groupbox:addedit ();
	edit.caption = "Number of Vars: ";
	edit.captionwidth = 100;
	edit.text = number_of_col;
	edit.translate = false;
	edit.enabled = false;
	wf_graph_col = edit;

	edit = groupbox:addedit ();
	edit.caption = "Number of Rows: ";
	edit.captionwidth = 100;
	edit.text = number_of_row;
	edit.translate = false;
	edit.enabled = true;
	wf_graph_row = edit;

	edit = groupbox:addedit ();
	edit.caption = "Width: ";
	edit.captionwidth = 100;
	edit.text = number_width;
	edit.translate = false;
	edit.enabled = true;
	wf_graph_w = edit;

	edit = groupbox:addedit ();
	edit.caption = "Height: ";
	edit.captionwidth = 100;
	edit.text = number_height;
	edit.translate = false;
	edit.enabled = true;
	wf_graph_h = edit;

	mygraph = system:creategraph(tonumber(wf_graph_col.text));
		
	-- Sets color for variable 1 und 2.
	mygraph:setcolor (0, 256 * 128); -- Green
	mygraph:setcolor (1, 65536 * 128); -- Blue

	-- Add key values (rows in an excel sheet)
	for i=1, tonumber(wf_graph_row.text) do
		mygraph:addrow(i);
	end;

	for i=1, tonumber(wf_graph_row.text) do
		mygraph:addvalue(0,i,i*100);
	end;
	for i=1, tonumber(wf_graph_row.text) do
		mygraph:addvalue(1,i,i*200);
	end;
	image = dialog:addimage();
	image.height = tonumber(wf_graph_h.text);
	image.width = tonumber(wf_graph_w.text);
	image:setgraph(mygraph);

	
	splitter = dialog:addsplitter ();
	splitter:settoleft ();
	button = splitter:addbutton ();
	button.caption = "OK";
	button.translate = false;
	button.onclick = "show_dialog_wf_graph_ok";
	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Cancel";
	button.translate = false;
	button.onclick = "show_dialog_wf_graph_oncancel";
	
	if dialog:show () then
        return true;
    end;
    return false;
end;

function show_dialog_wf_graph_ok ()
	number_of_col = tonumber(wf_graph_col.text);
	number_of_row = tonumber(wf_graph_row.text);
	number_height = tonumber(wf_graph_h.text);
	number_width = tonumber(wf_graph_w.text);
	dialog_wf_graph:close (true);
end;

function show_dialog_wf_graph_oncancel ()
	dialog_wf_graph_iscancel = true;
	dialog_wf_graph:close (false);
end;

function wf_graph ()
	system:setloggingtooglwindow(true);
	while dialog_wf_graph_haschanged do
		if show_dialog_wf_graph () then
			dialog_wf_graph_haschanged = true;
		else
			if dialog_wf_graph_iscancel then
				dialog_wf_graph_iscancel = false;
				dialog_wf_graph_haschanged = true;
				return;
			end;
		end;
	end;
end;

graph_file = "\\netfabb\\graph.png";
filename = application:getenvironmentvariable("APPDATA") ..graph_file;	
wf_graph();


