-- LUA Script for Autodesk Netfabb 2019.1
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes only
--==============================================================================

-- This script is a component script to be included, it does not contain its own main routine


CAD_extensions = { "3dm","3dxml","stp","step", "asm","catpart","cgr","dwg","fbx","iam",
				   "igs","iges","ipt","jt","model","neu","par","prt","psm","rvt",
				   "sat","skp","sldprt","wire","x_b","x_t","xas","xpr" }

MESH_extensions = { "3ds", "3mf", "amf", "gts", "ncm", "obj", "ply", "stl", "svx",
					"vrml", "x3d"}
					
					

function iscadfile (filename)
	local path,file,ext = string.match(filename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
	local ext = ext:lower()
	local isacadfile = false;
	for _,v in pairs(CAD_extensions) do
		if v == ext then
	    	isacadfile = true;
	    	break;
		end;
	end;
	return isacadfile;
end;

function loadcadfile (filename, root)
	local tesselationresolutionaccuracy = 4;
	local path,file,ext = string.match(filename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
	local ext = ext:lower()
	if iscadfile(ext) then
	    importer = system:createcadimport(0);
	    model = importer:loadmodel(filename, tesselationresolutionaccuracy)
		if model ~= nil then
			ANumberOfModels = model.entitycount;
			for i=0, ANumberOfModels-1 do
				mesh = model:createsinglemesh(i);
				luatraymesh = root:addmesh(mesh);
				luatraymesh.name = file;
			end;
			system:log("File '" .. filename .. "' added to tray.");
			return true;
		else
			system:log("File '" .. filename .. "' is empty");
			return false;
		end;
	else
		system:log("File '" .. filename .. "' is not a recognized CAD file format");
		return false;
	end;
end;

function ismeshfile (filename)
	local path,file,ext = string.match(filename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
	local ext = ext:lower()

	local isameshfile = false;
	for _,v in pairs(MESH_extensions) do
		if v == ext then
			isameshfile = true;
			break;
		end;
	end;
	return isameshfile;
end;

function loadmeshfile (filename, root)
	local path,file,ext = string.match(filename, "(.-)([^\\/]-%.?([^%.\\/]*))$")
	local ext = ext:lower()

	if ismeshfile(filename) then
		if ext == "3ds" then
			loaded_mesh = system:load3ds(filename);
		elseif ext == "3mf" then
			loaded_mesh = system:load3mf(filename);
		elseif ext == "amf" then
			loaded_mesh = system:loadamf(filename);
		elseif ext == "gts" then
			loaded_mesh = system:loadgts(filename);
		elseif ext == "ncm" then
			loaded_mesh = system:loadncm(filename);
		elseif ext == "obj" then
			loaded_mesh = system:loadobj(filename);
		elseif ext == "ply" then
			loaded_mesh = system:loadply(filename);
		elseif ext == "stl" then
			loaded_mesh = system:loadstl(filename);
		elseif ext == "svx" then
			loaded_mesh = system:loadsvx(filename);
		elseif ext == "vrml" then
			loaded_mesh = system:loadvrml(filename);
		elseif ext == "x3d" then
			loaded_mesh = system:loadx3d(filename);
		end;

		if loaded_mesh then
			luatraymesh = root:addmesh(loaded_mesh);
			luatraymesh.name = file;
			system:log("File '" .. filename .. "' added to tray.");
			return true;
		else
			system:log("File '" .. filename .. "' could not be added to tray.");
			return false;
		end;
	else
		system:log("File '" .. filename .. "' is not a recognized MESH file format");
		return false;
	end;
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

function removemeshesfromtray (tray)
	if tray == nil then
		system:log('removemeshesfromtray() -> tray  is nil!');
	else
		local root = tray.root;
		while root.meshcount > 0 do
	    	local traymesh = root:getmesh(0);
	      	root:removemesh(traymesh);
	      	root = tray.root
		end;
		while root.groupcount > 0 do
			local subgroup = root:getsubgroup(0);
			root:deletesubgroup(subgroup);
		end;
	end;
end;

function load_part ()
	local file_loaded;
	local root = tray.root;
	local filename = system:showopendialog("*");
		if iscadfile(filename) then
	       	file_loaded = loadcadfile(filename, root);
			application:triggerdesktopevent('updateparts') ;
		elseif ismeshfile(filename) then
			file_loaded = loadmeshfile(filename, root);
			application:triggerdesktopevent('updateparts') ;
		else 
			system:messagedlg("No valid file selected");
		end;
	return;
end;

function load_dir ()
	local xmlChild, filename, file_loaded;
	local root = tray.root;
	system:setloggingtooglwindow(true);
	local dirname = system:showdirectoryselectdialog(false, false, false);
	if dirname == "" then
		return;
	end
	local xmlfilelist = system:getallfilesindirectory(dirname);
	system:log("Attempting to load " .. xmlfilelist.childcount .. " file(s) from folder " .. dirname .. " ...");
	local numberoffiles = xmlfilelist.childcount;
	    -- Load each file in dirname
		for i=0,numberoffiles-1 do
		    xmlChild = xmlfilelist:getchildindexed(i);
		    filename = xmlChild:getchildvalue ("filename");
			if iscadfile(filename) then
	        	-- Load CAD file if extension found in CAD_extensions
				file_loaded = loadcadfile(filename, root)
			elseif ismeshfile(filename) then
				-- Load MESH file
				file_loaded = loadmeshfile(filename, root)
			else
				file_loaded = false;
			end;
			if file_loaded then
				system:log("Successfully loaded: " .. filename .. " in " .. dirname .. ".");
			else
				system:log("ERROR loading: " .. filename .. " in " .. dirname .. ".");
			end;
		end;
	application:triggerdesktopevent('updateparts') ;
	return;
end;

function load_fabb ()
	local newproject;
	local root, tray, mesh_index, newtray, newtrayroot;
	system:setloggingtooglwindow(true);
	local filename = system:showopendialog("fabbproject");
	system:log("Trying to load: " .. filename .. ".");
	local newproject = system:loadfabbproject(filename);
	local basetray = netfabbtrayhandler:gettray(0);
	local basetrayroot = basetray.root;
	for tray_index = 0, newproject.traycount - 1 do
		tray = newproject:gettray(tray_index);
		if tray == nil then
			system:log('  tray is nil!');
		else
			-- Get root meshgroup from tray
			root = tray.root;
			if tray_index > 0 then
				netfabbtrayhandler:addtray(tray.name, tray.machinesize_x, tray.machinesize_y, tray.machinesize_z);
				newtray = netfabbtrayhandler:gettray(tray_index);
			else
				newtray = netfabbtrayhandler:gettray(0);
			end;
			if newtray == nil then
				system:log('  tray is nil!');
			else
				newtrayroot = newtray.root;
				for mesh_index   = 0, root.meshcount - 1 do
					local traymesh = root:getmesh(mesh_index);
					newtrayroot:addmesh(traymesh.mesh,traymesh.name);
				end;
			end;
		end;
	end;
	application:triggerdesktopevent('updateparts') ;
	return;
end;

function save_fabb ()
	local tray, root, mesh_index, newtray, newroot;
	system:setloggingtooglwindow(true);
	local filename = system:showsavedialog("fabbproject");
	if system:fileexists(filename) then
		system:messagedlg("Can't save: " .. filename .. " - file already exists!");
		return;
	end;
	application:savefabbproject(filename);
	system:messagedlg(" " .. filename .. " saved!");
	return;
end;

function save_folder ()
	system:setloggingtooglwindow(true);
	local savefolder = system:showdirectoryselectdialog(true,true,true);
	--system:messagedlg("Selected folder" .. savefolder .. ".");
	return savefolder;	
end;

function empty_trays ()
	for tray_index = 0, netfabbtrayhandler.traycount - 1 do
		local tray = netfabbtrayhandler:gettray(tray_index);
		if tray == nil then
			system:log('  tray is nil!');
		else
			removemeshesfromtray(tray);
		end;
	end;
	application:triggerdesktopevent('updateparts') ;
	return;
end;


dialog_tray = nil;
tray_name = nil;
tray_x = nil;
tray_y = nil;
tray_z = nil;


function show_dialog_tray ()
	local dialog, groupbox, edit, combobox, splitter, button;

	dialog = application:createdialog ();
	dialog.caption = "Create Tray"
	dialog.width = 400;
	dialog.translatecaption = false;
	dialog_tray = dialog;
	
	groupbox =  dialog:addgroupbox ();
	groupbox.caption = "Parameters"
	groupbox.borderstyle = 1;
	groupbox.horizontalpadding = 10;
	groupbox.verticalpadding = 10;
	groupbox.translate = false;

	
	edit = groupbox:addedit ();
	edit.caption = "Name: ";
	edit.captionwidth = 100;
	edit.text = "New Tray";
	edit.translate = false;
	tray_name = edit;

	edit = groupbox:addedit ();
	edit.caption = "X (mm): ";
	edit.captionwidth = 100;
	edit.text = "100";
	edit.translate = false;
	tray_x = edit;

	edit = groupbox:addedit ();
	edit.caption = "Y (mm): ";
	edit.captionwidth = 100;
	edit.text = "100";
	edit.translate = false;
	tray_y = edit;

	edit = groupbox:addedit ();
	edit.caption = "Z (mm): ";
	edit.captionwidth = 100;
	edit.text = "100";
	edit.translate = false;
	tray_z = edit;

	splitter = dialog:addsplitter ();
	splitter:settoleft ();
	button = splitter:addbutton ();
	button.caption = "OK";
	button.translate = false;
	button.onclick = "show_dialog_tray_ok";
	splitter:settoright ();
	button = splitter:addbutton ();
	button.caption = "Cancel";
	button.translate = false;
	button.onclick = "show_dialog_tray_oncancel";
	
	if dialog:show () then
        return true;
    end;
    return false;
end;

function show_dialog_tray_ok ()
	dialog_tray:close (true);
end;

function show_dialog_tray_oncancel ()
	dialog_tray:close (false);
end;

function create_tray ()
	if show_dialog_tray () then
		-- create tray
		local x,y,z;
		x = tonumber (tray_x.text);
		y = tonumber (tray_y.text);
		z = tonumber (tray_z.text);
		if tray_name == nil or x == nil or y == nil or z == nil then
			system:messagedlg("Invalid input!");
			return;
		end;
		if x < 10 or x > 10000 then
			system:messagedlg("X (" .. tray_x.text .. ") is out of range!");
			return;
		end;
		if y < 10 or y > 10000 then
			system:messagedlg("Y (" .. tray_y.text .. ") is out of range!");
			return;
		end;
		if z < 10 or z > 10000 then
			system:messagedlg("Z (" .. tray_z.text .. ") is out of range!");
			return;
		end;
		netfabbtrayhandler:addtray(tray_name.text,x,y,z);
		application:triggerdesktopevent('updateparts') ;
		return;
	else
		return;
	end;
end;


-- GL routines

ERROR_NOERROR = 0;
GL_ERROR_COULDNOTCREATEGLCONTEXT = 1;
GL_ERROR_NOGLCONTEXT = 2;
GL_ERROR_INVALIDIMAGETYPE = 3;

--------------------------------------------------------------------------------------------------------
-- Rendering constants
--------------------------------------------------------------------------------------------------------
IMAGETYPE_PNG = 1;
IMAGETYPE_BMP = 2;
IMAGETYPE_JPG = 3;

glcontext = nil;

function gl_init (resolution_x, resolution_y)
  system:log ("Initializing OpenGL....");
  if glcontext ~= nil then
    glcontext:release ();
	glcontext = nil;
  end;
   system:log (resolution_x);
   system:log (resolution_y);
  glcontext = system:createoglcontext (resolution_x, resolution_y);
  system:log ("createoglcontext");
  if glcontext == nil then
    return GL_ERROR_COULDNOTCREATEGLCONTEXT;
  end;
  return ERROR_NOERROR;
end;

function gl_setbackgroundgradient (r_bl, g_bl, b_bl, r_br, g_br, b_br, r_tr, g_tr, b_tr, r_tl, g_tl, b_tl)
  if glcontext == nil then
    return GL_ERROR_NOGLCONTEXT;
  end;

  glcontext:setbackgroundgradient (r_bl, g_bl, b_bl, r_br, g_br, b_br, r_tr, g_tr, b_tr, r_tl, g_tl, b_tl);
  return ERROR_NOERROR;
end;


function gl_exportimage (filename, imagetype, quality)
  if glcontext == nil then
    return GL_ERROR_NOGLCONTEXT;
  end;
  
  glcontext:render ();
  glcontext:swapbuffers ();
  
  if imagetype == IMAGETYPE_PNG then
    glcontext:savetopng (filename);
  elseif imagetype == IMAGETYPE_BMP then
    glcontext:savetobmp (filename);
  elseif imagetype == IMAGETYPE_JPG then
    glcontext:savetojpeg (filename, quality);
  else
    return GL_ERROR_INVALIDIMAGETYPE;
  end;
  return ERROR_NOERROR;
end;

function gl_createmodel (mesh)
  if glcontext == nil then
    return -1;
  end;
  return glcontext:createmodel (mesh);  
end;

function gl_lookatmodel (modelid, eyex, eyey, eyez, upx, upy, upz, offset) 
  if glcontext == nil then
    return GL_ERROR_NOGLCONTEXT;
  end;
  glcontext:lookatmodelfromsurroundingsphere (modelid, eyex, eyey, eyez, upx, upy, upz, offset);
  return ERROR_NOERROR;
end;

function MoveMatrixZ(matrix, value)
  local tmp = matrix:get(2,2)
  matrix:set(3, 2, tmp + value);
end;

function getVolumeOfmesh(meshPar)
  local luamesh   = meshPar.mesh;
  local matrix   = meshPar.matrix;
  luamesh:applymatrix(matrix);
  return luamesh.volume;
end;

function checkErrorCodeMCpacker(errorcodepar)
    if errorcodepar == 0 then
        system:log('Monte Carlo Packing is finished. No problems were detected.');
    elseif errorcodepar == 1 then
        system:log('Monte Carlo Packing is finished. There is not enough place for all parts in the tray.');
    elseif errorcodepar == 2 then
        system:log('Monte Carlo Packing is finished. Some parts are too large for the given tray.');
    elseif errorcodepar == 3 then
        system:log('Monte Carlo Packing failed: All parts are too large for the given tray.');
    elseif errorcodepar == 4 then
        system:log('Monte Carlo Packing failed: There are no parts to pack.');
    elseif errorcodepar == 5 then
        system:log('Monte Carlo Packing failed: Starting from current positions is not possible.');
    else
        system:log('Monte Carlo Packing failed: Unknown error. ');
    end;
end;

function stringErrorCodeMCpacker(errorcodepar)
	local ret = "";
    if errorcodepar == 0 then
        ret = "Monte Carlo Packing is finished. No problems were detected.";
    elseif errorcodepar == 1 then
        ret = "Monte Carlo Packing is finished. There is not enough place for all parts in the tray.";
    elseif errorcodepar == 2 then
        ret = "Monte Carlo Packing is finished. Some parts are too large for the given tray.";
    elseif errorcodepar == 3 then
        ret = "Monte Carlo Packing failed: All parts are too large for the given tray.";
    elseif errorcodepar == 4 then
        ret = "Monte Carlo Packing failed: There are no parts to pack.";
    elseif errorcodepar == 5 then
        ret = "Monte Carlo Packing failed: Starting from current positions is not possible.";
    else
        ret = "Monte Carlo Packing failed: Unknown error.";
    end;
	return ret;
end;	

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end			

-- copy table of meshes to a tray
function copy2tray(meshtable, targettray)
	for i, traymesh in pairs(meshtable) do
		local luamesh = traymesh.mesh;
		local matrix = traymesh.matrix;
		luamesh:applymatrix(matrix);
		targettray.root:addmesh(luamesh,traymesh.name);
	end;
end;

-- remove table of meshes from a tray
function removefromtray(meshtable, targettray)
	for i, traymesh in pairs(meshtable) do
--		local luamesh = traymesh.mesh;
		targettray.root:removemesh(traymesh);
	end;
end;


-- MonteCarlo pack tray
function mc_packtray(Actualtray) 
  local packer = Actualtray:createpacker(Actualtray.packingid_montecarlo);
  packer.packing_quality = -1;
  packer.z_limit  = 0.0;    -- If z_limit is set to zero, the default value, MachineSizeZ will be used
  packer.start_from_current_positions = false;
  ret = packer:pack();
  Actualtray:updatetodesktop();
  return ret;
end;
	
-- Scanline pack tray
function sl_packtray(Actualtray) 
  local packer = Actualtray:createpacker(Actualtray.packingid_3d);
--  packer.allowrotationaxis = true;
  packer.anglecount = 0;
  packer.interlockingprotection = false;
  packer.minimizeoutbox = true;
  packer.rastersize = 1;
  ret = packer:pack();
  Actualtray:updatetodesktop();
  return ret;
end;

-- checks the required minimal Netfabb version for a lua script. majorversion: 8 = 2017, 9 = 2018, 10 = 2019 ...
function check_minimal_version (major, minor, build)
	local actual_major = system.majorversion;
	local actual_minor = system.minorversion;
	local actual_build = tonumber(system.buildnumber);
	if major > actual_major then
		return false;
	elseif major == actual_major then
		if minor > actual_minor then
			return false;
		elseif minor == actual_minor then
			if build > actual_build then
				return false;
			else
				return true;
			end;
		else -- minor < actual_minor
			return true;
		end;
	else -- mayor < actual_major
		return true;
	end;
end;