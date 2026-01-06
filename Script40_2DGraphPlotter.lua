-- LUA Script for Autodesk Netfabb 2022.2
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes
--==============================================================================

-- This script demonstrates the graph drawing utility
-- basic graph object usage example

dialog = nil;
dialog_image = nil;

LINE_NONE = 0;
LINE_SMOOTH = 1;
LINE_EXACT = 2;

NODE_NONE = 0;
NODE_CIRCLE = 1;
NODE_QUAD = 2;
NODE_DIAMOND = 3;

function DoDraw ()
    -- create draw object
    graphdrawer = system:creategraphdrawer();
    graphdrawer.title = 'Random Data';
    graphdrawer.caption_x = 'Time';
    graphdrawer.caption_y = 'Distance';
    graphdrawer.unit_x = 's';
    graphdrawer.unit_y = 'mm';
    graphdrawer.formatter_x = '\%.1fs';
    graphdrawer.formatter_y = '\%.0f';
    graphdrawer.grid_space_x = 10;
    graphdrawer.grid_space_y = 5;
    graphdrawer.font_size = 40;
    graphdrawer.margin = 60;
    graphdrawer.margin_right = 80;
    graphdrawer.margin_bottom = 130;
    graphdrawer.padding = 25;
    graphdrawer.border = 2;
    graphdrawer.grid = 1;
    graphdrawer.color_background = 0xFFFFFF;

    -- insert values to datasets
    dataset_all = graphdrawer:adddataset();
    dataset_all.legend = 'All';
    dataset_all.line_type = LINE_EXACT;
    dataset_all.node_type = NODE_NONE;
    dataset_all.line_size = 1;
    dataset_all.color_line = 0x888888;

    dataset_smooth = graphdrawer:adddataset();
    dataset_smooth.legend = 'Smoothed';
    dataset_smooth.line_type = LINE_SMOOTH;
    dataset_smooth.node_type = NODE_NONE;
    dataset_smooth.line_size = 10;
    dataset_smooth.line_smooth = 10;
    dataset_smooth.color_line = 0xBBBBBB;

    dataset_above = graphdrawer:adddataset();
    dataset_above.legend = 'Above';
    dataset_above.line_type = LINE_NONE;
    dataset_above.node_type = NODE_CIRCLE;
    dataset_above.node_size = 27;
    dataset_above.node_border = 3;
    dataset_above.color_node = 0xFF8888;
    dataset_above.color_node_border = 0x880000;

    dataset_below = graphdrawer:adddataset();
    dataset_below.legend = 'Below';
    dataset_below.line_type = LINE_NONE;
    dataset_below.node_type = NODE_QUAD;
    dataset_below.node_size = 23;
    dataset_below.node_border = 3;
    dataset_below.color_node = 0x8888FF;
    dataset_below.color_node_border = 0x000088;

    dataset_left = graphdrawer:adddataset();
    dataset_left.legend = 'Left';
    dataset_left.line_type = LINE_NONE;
    dataset_left.node_type = NODE_DIAMOND;
    dataset_left.node_size_x = 25;
    dataset_left.node_size_y = 40;
    dataset_left.node_border = 3;
    dataset_left.color_node = 0x88FF88;
    dataset_left.color_node_border = 0x008800;
    local offset = math.random() * 10;
    for i=0, 30 do
        local x = i + offset + (math.random()-0.5) * i * (30-i) * 0.03;
        local y = i + offset + (math.random()-0.5) * i * (30-i) * 0.03;

        dataset_all:addvalue(x, y);
        dataset_smooth:addvalue(x, y);
        if i < 10 then
            dataset_left:addvalue(x, y);
        elseif y > x then
            dataset_above:addvalue(x, y);
        else
            dataset_below:addvalue(x, y);
        end;
    end;

    -- render into generic image object
    local graph_image = graphdrawer:draw(dialog_image.width, dialog_image.height);

    -- save to disk
    -- graph_image:saveto('D:/Temp/RandomDataPlot.png');
	
    -- show result in dialog
    dialog_image:setimage(graph_image);
end;

function DoCancel ()
    system:log('close');
    dialog:close (false);
end;

function ShowDialog ()
    local dlg_width = 700;
    dialog = application:createdialog ();
    dialog.caption = "Random Data Plotter"
    dialog.width = dlg_width;
    dialog.translatecaption = false;

    dialog_image = dialog:addimage();
    dialog_image.width = dlg_width;
    dialog_image.height = 500;

    local splitter = dialog:addsplitter ();
    splitter:settoleft ();
    local button = splitter:addbutton ();
    button.caption = "Draw";
    button.translate = false;
    button.onclick = "DoDraw";
	
    splitter:settoright ();
    button = splitter:addbutton ();
    button.caption = "Cancel";
    button.translate = false;
    button.onclick = "DoCancel";

    DoDraw();
	
    if dialog:show () then
        return true;
    end;
    return false;	
end;

system:setloggingtooglwindow(true);
ShowDialog ()
