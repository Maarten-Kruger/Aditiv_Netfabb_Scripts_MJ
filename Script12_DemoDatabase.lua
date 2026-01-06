-- LUA Script for Autodesk Netfabb 2019.0
-- Copyright by Autodesk 2018
-- This script is for demonstration purposes only
--==============================================================================

-- This script is for the LUA Automation module in the main module
-- The variable tray is predefined and corresponds to the current buildroom

-- You need to create your own SQL Server, create an user for the SQL server and 
-- start an ODBC Service 

-- This example only for demonstration purposes only to (create), write, and read from a SQL database

ODBC_DSNNAME = "test";
ODBC_USER = "demouser";
ODBC_PASSWORD = "LL10203040";

sql_connection = 0;


function init_db ()
	system:log ('Connecting to database...');
	sql_connection = system:connecttoodbc (ODBC_DSNNAME, ODBC_USER, ODBC_PASSWORD);		
    system:log ('Connected to database...');
end;

function CreateDB () 
    local query_string, uuid, insertid;
   	uuid = sql_connection:getuniquestring ();
	query_string = string.format ('CREATE TABLE netfabb_tray (meshname varchar(255), meshsize FLOAT, insert_uuid varchar(255) )');
	sql_connection:sendquery (query_string);
    
end;

function DemoDB_InsertIntoDatabase (meshnameValue, meshsizeValue)
   local query_string, uuid, insertid;
   	uuid = sql_connection:getuniquestring ();
	query_string = string.format ('INSERT INTO netfabb_tray (meshname, meshsize, insert_uuid) VALUES (\'%s\', \'%d\', \'%s\' )', 
			                            meshnameValue, meshsizeValue, uuid);
    system:log (query_string);
	sql_connection:sendquery (query_string);
    
    
end;

function DemoDB_GetMeshSizeFromMeshName (meshname)
      local query_string, uuid, insertid;

    -- Since ODBC does not support InsertID-Calls, we simply select back our UUID
	query_string = string.format ('SELECT meshsize FROM netfabb_tray WHERE meshname = \'%s\' ', meshname);
	sql_connection:sendquery (query_string);
	
	-- Extract and parse result
	result = sql_connection:getresult ();
	if result:getfieldcount() > 0 then
		insertid = result:getfield (0);
	else
		insertid = -1; -- if there has been an error, we won't find any tray
	end;
	result:release ();	
    
    return insertid;   

end;

    
init_db();
--CreateDB (); This needs be run the first time
system:log ('table created');
local root = tray.root;                                                        -- Iterate meshes in group
for mesh_index    = 0, root.meshcount - 1 do
   local mesh      = root:getmesh(mesh_index);
   local meshobject = mesh.mesh;
   DemoDB_InsertIntoDatabase(mesh.name, meshobject.volume);
end;

--For demo purposes only verify
 for mesh_index    = 0, root.meshcount - 1 do
   local mesh      = root:getmesh(mesh_index);
   local meshobject = mesh.mesh;
   local value = DemoDB_GetMeshSizeFromMeshName(mesh.name);
   system:log (value);
end;

 sql_connection:disconnect();
