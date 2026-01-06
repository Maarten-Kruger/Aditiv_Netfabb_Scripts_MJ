-- LUA Script for Autodesk Netfabb 2025.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Finds new orientation based on least support volume

system:setloggingtooglwindow(true);

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

    -- Iterate over meshes in tray
    for i, traymesh in pairs(meshes) do
      system:log("Orient part: " .. traymesh.name);
      local luamesh   = traymesh.mesh;
      luamesh:applymatrix(traymesh.matrix);

      local orienter = luamesh:create_partorienter()
	  orienter.cutoff_degree = 45;
	  orienter.smallest_distance_between_minima_degree = 30;
	  orienter.rotation_axis = 'arbitrary'
	  orienter.distance_from_platform = 10;
	  orienter.support_bottom_surface = true;
	  -- Optionally limit height
	  -- orienter:limitbuildheight(250);
	  orienter:search_orientation_with_progress();
	  orientation = orienter:get_best_solution_for('support_volume');
	  local matrix = orienter:get_matrix_from_solution(orientation);
	  luamesh:applymatrix(matrix);
	  newmesh = root:addmesh(luamesh)
	  newmesh.name = traymesh.name .. ' (oriented)';
    end;

end;

           