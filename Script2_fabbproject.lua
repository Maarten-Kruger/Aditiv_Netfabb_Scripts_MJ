-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- Loads and manipulates a fabbproject independently from the Desktop Appplication 
-- You have to create your own Fabbproject before you execute the script. It has to be in the same folder as the netfabb exe, 
-- if you do not provide a path to the file.
-- The Project should also not be opened by the Desktop Aplication


-- test.fabbproject provided by the user. If no path is given, the file needs to be present in a directory, which is searched by the 
-- application.     
filename = 'd:\\demo\\test.fabbproject';
      

  
system:setloggingtooglwindow(true);
system:log(filename);

fabbproject = system:loadfabbproject(filename);
local OutPutDir = 'd:\\demo\\output\\';
-- Iterate trays
for tray_index = 0, fabbproject.traycount - 1 do
  local tray = fabbproject:gettray(tray_index);
  if tray == nil then
    system:log('  tray is nil!');
  else
    -- Get root meshgroup from tray
    local root = tray.root;

    -- Iterate meshes in group
    for mesh_index    = 0, root.meshcount - 1 do
      local rotate    = 0.5 * mesh_index;
      local translate = 15 * mesh_index;
      local scale     = 1 / (mesh_index + 1);
      local mesh      = root:getmesh(mesh_index);
      local luamesh   = mesh.mesh;
      
      -- rotate mesh
      mesh:rotate(1, 0, 0, rotate);
     
      -- translate mesh
      mesh:translate(translate, 0, translate);
      
      -- scale mesh
      mesh:scale(scale, scale, scale);
      
      if not system:directoryexists(OutPutDir) then
        system:createdirectory(OutPutDir);
      end;
      
      -- export mesh as STL (source mesh - no transformations written)
      mesh.mesh:savetostl(OutPutDir .. mesh.name ..tostring(tray_index) .. '_source.stl');
      
      -- export mesh to all formats with transformations
      mesh:savetostl     (OutPutDir .. mesh.name ..tostring(tray_index).. '.stl'      );
     
    end;

  end;
end;

-- save the modified fabbproject to a new .fabbproject file
system:log('Save \'copy.fabbproject\' ..');
fabbproject:savetofile('copy.fabbproject');

-- log all options that were not saved
if fabbproject.notsavedoptions ~= "" then
  system:log('===== not saved options =====');
  system:log(fabbproject.notsavedoptions);
  system:log('=============================');
end;
