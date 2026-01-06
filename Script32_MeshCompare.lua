-- LUA Script for Autodesk Netfabb 2021.0
-- Copyright by Autodesk 2020
-- This script is for demonstration purposes
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom
-- Compares to selected meshes and displays the mesh distances in a histogram

local insertMeshesIntoTable;
insertMeshesIntoTable = function (meshgroup, Outtable)
  for mesh_index    = 0, meshgroup.meshcount - 1 do
      local traymesh      = meshgroup:getmesh(mesh_index);
      table.insert(Outtable, traymesh);
  end;
  for group_index = 0, meshgroup.groupcount - 1 do
     subgroup = meshgroup:getsubgroup(group_index);
     insertMeshesIntoTable(subgroup, Outtable);
  end;
end;

dialog = nil;
histogram = nil;
image = nil;
edit_select1 = nil;
edit_select2 = nil;
distances1 = system:createarray()
distances2 = system:createarray()
copy1 = nil;
copy2 = nil;

function SelectDistance()
  -- select bar in graph and update image
  histogram:selectatpixel(image.width, image.height, image.mousex, image.mousey);
  local histogram_image = histogram:drawhistogram(image.width, image.height);
  image:setimage(histogram_image);

  edit_select1.text = string.format("%.2f mm", histogram.selectionstart);
  edit_select2.text = string.format("%.2f mm", histogram.selectionend);
end

function DoCancel()
  if dialog ~= nil then
    dialog:close (false);
  end;
end

function ColorMesh(mesh, distances)
  local nodeindices = system:createarray()
  local theshold = histogram.selectionstart
  mesh:gettrianglenodeindices(nodeindices)
  mesh:colortriangles(128,128,128,128);
  for i=0, mesh.facecount-1 do
    for j=0, 2 do
      index = nodeindices:get(i*3+j)
      dist = distances:get(index)
      if dist > theshold then
        mesh:colortriangle(i,0,0,255,254);
      end
      if dist < -theshold then
        mesh:colortriangle(i,255,0,0,254);
      end
    end
  end
end

function PaintMesh()
  ColorMesh(copy1, distances1)
  ColorMesh(copy2, distances2)

  local root = tray.root
  newtraymesh = root:addmesh(copy1);
  newtraymesh.name = "meshcompare 1";
  newtraymesh = root:addmesh(copy2);
  newtraymesh.name = "meshcompare 2";
  DoCancel()
end;

function CompareShowDistances(mesh1, mesh2)
  -- Get meshes with applied matrix
  luamesh1 = mesh1.mesh
  luamesh2 = mesh2.mesh
  copy1 = luamesh1:dupe()
  copy2 = luamesh2:dupe()
  copy1:applymatrix(mesh1.matrix)
  copy2:applymatrix(mesh2.matrix)

  -- Do comparison, get distances
  copy1:comparegetdistances(copy2, distances1, distances2)

  -- Create histogram by distances
  histogram = system:createhistogram();
  histogram.caption_x = 'Distance';
  histogram.caption_y = 'Occurence';
  histogram.bar_count = 25;
  histogram.unit = ' mm';
  hausdorff = 0
  for i=0, distances1.length-1 do
    local dist = math.abs(distances1:get(i))
    hausdorff = math.max(hausdorff, dist)
    histogram:addvalue(dist)
  end
  for i=0, distances2.length-1 do
    local dist = math.abs(distances2:get(i))
    hausdorff = math.max(hausdorff, dist)
    histogram:addvalue(dist)
  end

  dialog = application:createdialog ();
  dialog.caption = "Mesh Compare"
  dialog.width = 500;
  dialog.translatecaption = false;
  local groupbox =  dialog:addgroupbox ();
  groupbox.caption = ""
  groupbox.translate = false;

  local edit = groupbox:addedit ();
  edit.caption = "Mesh 1";
  edit.captionwidth = 150;
  edit.text = mesh1.name;
  edit.translate = false;
  edit.enabled = false;

  local edit = groupbox:addedit ();
  edit.caption = "Mesh 2";
  edit.captionwidth = 150;
  edit.text = mesh2.name;
  edit.translate = false;
  edit.enabled = false;

  local edit = groupbox:addedit ();
  edit.caption = "Hausdorff distance";
  edit.captionwidth = 150;
  edit.text = string.format("%.2f mm", hausdorff);
  edit.translate = false;
  edit.enabled = false;

  edit_select1 = groupbox:addedit ();
  edit_select1.caption = "Selection start";
  edit_select1.captionwidth = 150;
  edit_select1.text = "---";
  edit_select1.translate = false;
  edit_select1.enabled = false;

  edit_select2 = groupbox:addedit ();
  edit_select2.caption = "Selection end";
  edit_select2.captionwidth = 150;
  edit_select2.text = "---";
  edit_select2.translate = false;
  edit_select2.enabled = false;

  image = groupbox:addimage ();
  image.width = dialog.width - 15
  image.height = 300
  local histogram_image = histogram:drawhistogram(image.width, image.height);
  image:setimage(histogram_image);
  image.onclick = "SelectDistance";

  local splitter = groupbox:addsplitter ();
  splitter:settoleft ();
  local button = splitter:addbutton ();
  button.caption = "Paint Mesh";
  button.translate = false;
  button.onclick = "PaintMesh";

  splitter:settoright ();
  button = splitter:addbutton ();
  button.caption = "Cancel";
  button.translate = false;
  button.onclick = "DoCancel";

  dialog:show()
end

system:setloggingtooglwindow(true);
if tray == nil then
  system:log('tray is nil!');
else
  local root = tray.root;
  -- Collect meshes in the tray
  local meshes = {};
  insertMeshesIntoTable(root, meshes);
  mesh1 = nil
  mesh2 = nil
  -- Iterate meshes in group
  for i, traymesh in pairs(meshes) do
    local luamesh   = traymesh.mesh;
    if traymesh.selected then
      if mesh1 == nil then
        mesh1 = traymesh
      elseif mesh2 == nil then
        mesh2 = traymesh
      end
    end
  end;
  if (mesh1 == nil) or (mesh2 == nil) then
    system:log('please select two meshes!');
  else
    CompareShowDistances(mesh1, mesh2)
  end
end;

