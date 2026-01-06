-- LUA Script for Autodesk Netfabb Professional 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- This uses the plugin functionality of netfabb. One can execute self-written c++ functions in a 
-- seperate dll inside the LUA framework. The dll needs to implement the netfabb SDK header and plugin calls.   
-- On request you can get the header files, and an example project dll 
-- Here we call the example dll (example_plugin.dll)


example_plugin = nil;

function plugin_rotate (mesh)

  -- load PLUGIN plugin if not yet existing...
	if example_plugin == nil then
		example_plugin = system:loadplugin ("example_plugin");
	end;

	
  if mesh == nil then return; end;
  
	-- Create Message and send to plugin...
	message = example_plugin:createmessage ("plugin_action_rotate");
	message:addmesh ("mesh", mesh);
	message:handle ();

	replymessage = example_plugin:popsyncmessage ();
	if replymessage.identifier == 'plugin_rotate_reply' then
		
		system:log('Perform rotation');
		rotation = replymessage:getmatrix("rotation_matrix")
		mesh:transform(rotation);
	end;
end;

function plugin_noise (mesh)

  -- load PLUGIN plugin if not yet existing...
	if example_plugin == nil then
		example_plugin = system:loadplugin ("example_plugin");
	end;

  noise_mesh = nil;	
  if mesh == nil then return; end;
  
  -- Create Message and send to plugin...
  message = example_plugin:createmessage ("plugin_action_noise");
  message:addmesh ("mesh", mesh);
  message:handle ();

  replymessage = example_plugin:popsyncmessage ();
  if replymessage.identifier == 'plugin_noise_reply' then
		
		system:log('create new part with noise');
		noise_mesh = replymessage:extractmesh("noise_mesh");
			
	end;
  return noise_mesh;  
end;


if tray == nil then
    system:log('  tray is nil!');
  else
    -- Get root meshgroup from tray
    local root = tray.root;
    -- Iterate meshes in group
    local meshes = {};
    for mesh_index    = 0, root.meshcount - 1 do  
      local traymesh      = root:getmesh(mesh_index);
      table.insert(meshes, traymesh);
    end;
    
    for i, traymesh in pairs(meshes) do   
      local luamesh   = traymesh.mesh;
      newMesh = luamesh:dupe();
        
      noisemesh = plugin_noise(newMesh) 
      root:addmeshsource(noisemesh);
  
    end;  
 end;  

