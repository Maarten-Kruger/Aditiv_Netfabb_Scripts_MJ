-- System_Probe.lua
-- Probes the Netfabb environment for available import methods and DLL status.

local log_path = "C:\\Users\\Public\\Documents\\netfabb_probe_log.txt"
if system and system.logtofile then
    pcall(function() system:logtofile(log_path) end)
end

local function log(msg)
    if system and system.log then system:log(msg) end
end

log("--- Starting System Probe ---")

-- 1. Test CAD Importers
log("1. Testing createcadimport indices:")
for i = 0, 5 do
    local ok, imp = pcall(function() return system:createcadimport(i) end)
    if ok and imp then
        log("  createcadimport(" .. i .. "): Success")
    else
        log("  createcadimport(" .. i .. "): Failed")
    end
end

-- 2. Test Potential System Methods
log("2. Testing system methods:")
local methods = {
    "importfile", "import", "loadstep", "loadstp", "loadcad", "loadmodel",
    "load3mf", "loadstl" -- Control group
}

for _, m in ipairs(methods) do
    if system[m] then
        log("  system:" .. m .. " exists (Type: " .. type(system[m]) .. ")")
    else
        log("  system:" .. m .. " does NOT exist")
    end
end

-- 3. DLL Dependency Check (Indirect)
-- We try to load a dummy model with importer 0 to trigger the DLL error explicitly
log("3. Triggering DLL Check:")
local ok_imp, importer = pcall(function() return system:createcadimport(0) end)
if ok_imp and importer then
    local ok_load, res = pcall(function() return importer:loadmodel("dummy.stp") end)
    log("  loadmodel result: " .. tostring(ok_load) .. " / " .. tostring(res))
else
    log("  Skipping loadmodel check (importer 0 failed creation)")
end

pcall(function() system:inputdlg("Probe Complete. Check log: " .. log_path, "Done", "OK") end)
