-- LUA Script for Autodesk Netfabb Professional 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes only
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom

-- The script demonstrate the use of the OGL framework of the LUA Automation module to create a snapshot 


ERROR_NOERROR = 0;
ERROR_COULDNOTCREATEGLCONTEXT = 1;
ERROR_NOGLCONTEXT = 2;
ERROR_INVALIDIMAGETYPE = 3;

--------------------------------------------------------------------------------------------------------
-- Rendering constants
--------------------------------------------------------------------------------------------------------
IMAGETYPE_PNG = 1;
IMAGETYPE_BMP = 2;
IMAGETYPE_JPG = 3;

glcontext = nil;

system:logtofile ('LUAoutput.txt');  

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
    return ERROR_COULDNOTCREATEGLCONTEXT;
  end;
  return ERROR_NOERROR;
end;

function gl_setbackgroundgradient (r_bl, g_bl, b_bl, r_br, g_br, b_br, r_tr, g_tr, b_tr, r_tl, g_tl, b_tl)
  if glcontext == nil then
    return ERROR_NOGLCONTEXT;
  end;

  glcontext:setbackgroundgradient (r_bl, g_bl, b_bl, r_br, g_br, b_br, r_tr, g_tr, b_tr, r_tl, g_tl, b_tl);
  return ERROR_NOERROR;
end;


function gl_exportimage (filename, imagetype, quality)
  if glcontext == nil then
    return ERROR_NOGLCONTEXT;
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
    return ERROR_INVALIDIMAGETYPE;
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
    return ERROR_NOGLCONTEXT;
  end;
  glcontext:lookatmodelfromsurroundingsphere (modelid, eyex, eyey, eyez, upx, upy, upz, offset);
  return ERROR_NOERROR;
end;

-- create ogl context
gl_init (1024, 768);

local outname = 'd:\\test.png';

if tray == nil then
    system:log('  tray is nil!');
  else
    -- Get root meshgroup from tray
    local root = tray.root;
    system:log('  tray with ' .. tostring(root.meshcount) .. ' meshes');
    -- Iterate meshes in group
    for mesh_index    = 0, root.meshcount - 1 do
      local traymesh      = root:getmesh(mesh_index);
      local luamesh   = traymesh.mesh;
      
      -- make model out of mesh
      modelid = gl_createmodel (luamesh);

      -- set background
      gl_setbackgroundgradient(0, 0, 255, 0, 255, 0, 255, 0, 0, 0, 255, 255);

      -- add model to scene  
      glcontext:addmodeltoscene (modelid);

      -- set camera position
      gl_lookatmodel (modelid, 0, -1, 0, 0, 0, 1, 0.55);

      -- save preview image  
      gl_exportimage (outname, IMAGETYPE_PNG, 90); 

    end;  
end;



