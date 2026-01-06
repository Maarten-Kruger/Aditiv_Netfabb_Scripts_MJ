-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Loads and slice meshes in a build platform 


system:setloggingtooglwindow(true);
if tray == nil then
    system:log('  tray   is nil!');
  else
    local root = tray.root;
   
    for mesh_index    = 0, root.meshcount - 1 do
      
      local mesh      = root:getmesh(mesh_index);
      local luamesh   = mesh.mesh;
      local matrix   = mesh.matrix;
      newMesh = luamesh:dupe();
      local matrix   = mesh.matrix;     
      newMesh:applymatrix(matrix);
      local  outbox = newMesh:calcoutbox();
      local Layersize = 1; 
      
      local FromZ = outbox.minz;
      local ToZ = outbox.maxz;
      local CreateInMemory = true;
      slice = system:slicemesh(newMesh, Layersize, FromZ, ToZ, CreateInMemory);
      local filename = 'mesh' .. tostring(mesh_index) .. '.sli';
      --(0: USF, 1: CLI, 2: SLI, 3: CLS, 4: SLC);  
      slice:savetofile(filename, 2, Layersize, FromZ, ToZ);
      
    end;  
end;
