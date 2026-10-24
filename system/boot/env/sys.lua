local sys = {}

local function assert(v, msg, lvl)
	if not v then
		error(msg or "assertion failed!", lvl + 1)
	end
	return v
end

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
	assert(type(name) == "string", "name must be string", 2)
	assert(type(version) == "number" or version == nil, "version must be int or nil", 2)
	assert(math.floor(version) == version, "version must be an integer", 2)

	if version then
		return extensions[name] == version
	end
	return extensions[name] ~= false and extensions[name] ~= nil
end

function sys.sleep(seconds)
	assert(type(seconds) == "number", "seconds must be number", 2)

	if seconds < 0 then
		return nil, "EINVAL", "cannot sleep for a negative amount of time"
	end
	local endtime = chip.getTime() + seconds
	while endtime > chip.getTime() do
		coroutine.yield()
	end
end

return sys
