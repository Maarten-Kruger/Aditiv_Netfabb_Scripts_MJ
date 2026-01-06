-- LUA Script for Autodesk Netfabb 2020.2
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the slice commander
-- basic graph object usage example
dialog_input = nil;
temp_dir_input = nil;
width_input = nil;
height_input = nil;
result_image = nil;
diff_1_image = nil;
diff_2_image = nil;
histogram = nil;
img_process = nil;
current_slice_input = nil;
current_equal_input = nil;

function SelectZ ()
	-- select bar in graph and update image
	histogram:selectatpixel(result_image.width, result_image.height, result_image.mousex, result_image.mousey);
	local histogram_image = histogram:drawgraph(result_image.width, result_image.height);
	result_image:setimage(histogram_image);

	-- load slice diff
	if histogram.selection >= 0 then
		local selection = histogram.selection+1;
		local temp = temp_dir_input.text;
		local diff = img_process:loadimage(temp .. 'slice_diff_1_' .. selection .. '.png');
		diff_1_image:setimage(diff);
		diff = img_process:loadimage(temp .. 'slice_diff_2_' .. selection .. '.png');
		diff_2_image:setimage(diff);
		dialog_input:rebuild();
		current_slice_input.text = selection .. ' #';
		current_equal_input.text = string.format('%02.2f', histogram:getvalue(selection)) .. ' %';
	end;
end;

function DoCompare ()
	system:log('start slice compare');
	
	-- get parameter
	local temp = temp_dir_input.text;
	local slice_1 = slicelist:getslice(0);
	local slice_2 = slicelist:getslice(1);
	count = math.max(slice_1.layercount, slice_2.layercount);
	
	local left = slice_1.minx;
	if slice_2.minx < left then
		left = slice_2.minx;
	end;
	local right = slice_1.maxx;
	if slice_2.maxx > right then
		right = slice_2.maxx;
	end;
	local top = slice_1.miny;
	if slice_2.miny < top then
		top = slice_2.miny;
	end;
	local bottom = slice_1.maxy;
	if slice_2.maxy > bottom then
		bottom = slice_2.maxy;
	end;

	local slice_width = right - left;
	local slice_height = bottom - top;
	local renderer_1 = slice_1:createimagerenderer(count, slice_1.layersize);
	renderer_1.width = tonumber(width_input.text);
	renderer_1.dpix = 25 * (renderer_1.width / slice_width);
	renderer_1.height = tonumber(height_input.text);
	renderer_1.dpiy = 25 * renderer_1.height / slice_height;	
	renderer_1.left = -left * renderer_1.width / slice_width;
	renderer_1.top = -top * renderer_1.height / slice_height;
	renderer_1.writeclosedcontours = true;
	renderer_1.writeopencontours = true;
	renderer_1.fillclosedcontours = false;
	renderer_1.writehatches = true;
	local renderer_2 = slice_2:createimagerenderer(count, slice_2.layersize);
	renderer_2.width = renderer_1.width;
	renderer_2.dpix = renderer_1.dpix;
	renderer_2.height = renderer_1.height;
	renderer_2.dpiy = renderer_1.dpiy;
	renderer_2.left = renderer_1.left;
	renderer_2.top = renderer_1.top;
	renderer_2.writeclosedcontours = renderer_1.writeclosedcontours;
	renderer_2.writeopencontours = renderer_1.fillclosedcontours;
	renderer_2.fillclosedcontours = renderer_1.fillclosedcontours;
	renderer_2.writehatches = renderer_1.writehatches;
	
	-- render into zip archive
	system:log('render slices');
	renderer_1:exportpng(temp .. 'slice_1.zip');
	renderer_2:exportpng(temp .. 'slice_2.zip');
	
	-- extract archives
	local archive_1 = system:openzip(temp .. 'slice_1.zip');	
	local archive_2 = system:openzip(temp .. 'slice_2.zip');

	
	-- do compare
	system:log('compare images ' .. math.min(slice_1.layercount-1, slice_2.layercount-1));
	img_process = system:createimageprocessing();
	histogram = system:createhistogram();
	histogram.caption_x = 'Slice Z Value →';
	histogram.caption_y = 'Equal Percentage →';
	histogram.bar_count = 25;
	histogram.unit = '%';
	histogram:setcustomminmax(0, 100);
	system:showprogressdlg(true);
	
	for i=0, count-1 do
		-- axtract slice images from archive
		archive_1:extractfile(archive_1:getfilename(i), temp .. 'slice_1_' .. i .. '.png');
		archive_2:extractfile(archive_2:getfilename(i), temp .. 'slice_2_' .. i .. '.png');

		-- load and prepare images
		local image_1 = img_process:loadimage(temp .. 'slice_1_' .. i .. '.png');
		local image_2 = img_process:loadimage(temp .. 'slice_2_' .. i .. '.png');
		local equal_amount = image_1:comparebyfiltercolor(image_2, 0x000000);
		histogram:addvalue(equal_amount);
		local delta = image_1:clone();
		delta:deltato(image_2);
		delta:invert();
		delta:colormask(delta, 0x000000, 0x0000FF);
		--delta:colortotransparent(0xFFFFFF);
		--delta:setcolor(0x0000FF);
		image_1:imagemask(delta, 0xFFFFFF);
		image_2:imagemask(delta, 0xFFFFFF);
		
		image_1:saveto(temp .. 'slice_diff_1_' .. i .. '.png');
		image_2:saveto(temp .. 'slice_diff_2_' .. i .. '.png');
		system:setprogress(100 * i / count);
	end;
	archive_1:closearchive();
	archive_2:closearchive();

	system:hideprogressdlg();
	result_image.height = 350;
	local histogram_image = histogram:drawgraph(result_image.width, result_image.height);
	histogram_image:saveto(temp .. 'histogram.png');
	
	-- show result
	result_image:setimage(histogram_image);
	result_image.onclick = "SelectZ";
	dialog_input:rebuild();
end;

function DoCancel ()
	system:log('slice compare canceled by user');
	dialog_input:close (false);
end;

function CompareSlices (slice_1, slice_2)
	system:log('show slice compare options');
	
	dialog_input = application:createdialog ();
	dialog_input.caption = "Slice Compare"
	dialog_input.width = 1000;
	dialog_input.translatecaption = false;

	local groupbox =  dialog_input:addgroupbox ();
	groupbox.caption = ""
	groupbox.translate = false;
	
	local splitter = groupbox:addsplitter ();
	splitter:settoleft ();	

	local groupbox_setting =  splitter:addgroupbox ();
	groupbox_setting.caption = "Slice Compare Settings"
	groupbox_setting.borderstyle = 1;
	groupbox_setting.horizontalpadding = 10;
	groupbox_setting.verticalpadding = 10;
	groupbox_setting.translate = false;
	local edit_width = 150;
	
	local edit = groupbox_setting:addedit ();
	edit.caption = "Input Slice 1";
	edit.captionwidth = edit_width;
	edit.text = slice_1.name;
	edit.translate = false;
	edit.enabled = false;
	
	local edit = groupbox_setting:addedit ();
	edit.caption = "Input Slice 2";
	edit.captionwidth = edit_width;
	edit.text = slice_2.name;
	edit.translate = false;
	edit.enabled = false;
	
	width_input = groupbox_setting:addedit ();
	width_input.caption = "Image Width";
	width_input.captionwidth = edit_width;
	width_input.text = "200";
	width_input.translate = false;
	width_input.enabled = true;
	
	height_input = groupbox_setting:addedit ();
	height_input.caption = "Image Height";
	height_input.captionwidth = edit_width;
	height_input.text = "200";
	height_input.translate = false;
	height_input.enabled = true;
	
	temp_dir_input = groupbox_setting:addedit ();
	temp_dir_input.caption = "Temporary Folder";
	temp_dir_input.captionwidth = edit_width;
	local temp_file = system:gettempfilename('.tmp');
	local temp_dir = system:extractfilepath(temp_file, true);
	temp_dir_input.text = temp_dir;
	temp_dir_input.translate = false;
	temp_dir_input.enabled = true;

	current_slice_input = groupbox_setting:addedit ();
	current_slice_input.caption = "Current Slice Index";
	current_slice_input.captionwidth = edit_width;
	current_slice_input.text = "--";
	current_slice_input.translate = false;
	current_slice_input.enabled = false;

	current_equal_input = groupbox_setting:addedit ();
	current_equal_input.caption = "Current Slice Equality";
	current_equal_input.captionwidth = edit_width;
	current_equal_input.text = "--";
	current_equal_input.translate = false;
	current_equal_input.enabled = false;
	
	splitter:settoright ();

	result_image = splitter:addimage();
	result_image.width = dialog_input.width / 2;
	result_image.height = 50;

	local groupbox_diff =  dialog_input:addgroupbox ();
	groupbox_diff.caption = "Difference for Slice 1 and Slice 2"
	groupbox_diff.translate = false;

	local splitter = groupbox_diff:addsplitter ();
	splitter:settoleft ();

	diff_1_image = splitter:addimage();
	diff_1_image.width = dialog_input.width / 2;
	diff_1_image.height = 50;
	
	splitter:settoright();

	diff_2_image = splitter:addimage();
	diff_2_image.width = dialog_input.width / 2;
	diff_2_image.height = 50;

	local spacer = dialog_input:addspacer();
	spacer.height = 20;

	local splitter = dialog_input:addsplitter ();
	splitter:settoleft ();
	local button = splitter:addbutton ();
	button.caption = "Compare";
	button.translate = false;
	button.onclick = "DoCompare";
	
	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Cancel";
	button.translate = false;
	button.onclick = "DoCancel";
	
	if dialog_input:show () then
        return true;
    end;
    return false;	
end;

system:setloggingtooglwindow(true);
system:log('slice-list has ' .. slicelist.count .. 'entries');
if slicelist.count > 1 then
	CompareSlices(slicelist:getslice(0), slicelist:getslice(1));
else
	system:log('slice compare failed, because slicelist has not enough entries');
	system:messagedlg('Please select two slices for comparison');
end;
