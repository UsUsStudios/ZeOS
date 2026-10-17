local sys = {}

local extensions = {}
-- add an extension to the list; string, int (version)
local function add(extension, version)
	extensions[extension] = version
end

add("core", 2)
--add("ext.screen")
--add("ext.sppRemote")
--add("ext.stdio")
--add("ext.env")
--add("ext.time")
--add("ext.proc")
--add("ext.user")
--add("ext.system")
--add("ext.spp")
--add("ext.dpp")
--add("ext.rpp")

function sys.getOSName()
	return OS_NAME
end

function sys.getOSVersion()
	return OS_VERSION
end

function sys.getExtensions()
	return extensions
end

function sys.hasExtension(name, version)
	if version then
		return extensions[name] == version
	end
	return extensions[name] ~= false and extensions[name] ~= nil
end

function sys.sleep(seconds)
	if seconds < 0 then
		return nil, "EINVAL", "cannot sleep for a negative amount of time"
	end
	local endtime = chip.getTime() + seconds
	while endtime > chip.getTime() do
		coroutine.yield()
	end
end

return sys
