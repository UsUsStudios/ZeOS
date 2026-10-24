local env = {}

local function assert(v, msg, lvl)
	if not v then
		error(msg or "assertion failed!", lvl + 1)
	end
	return v
end

local function shallowcopy(t)
	local copy = {}
	for key, value in pairs(t) do
		copy[key] = value
	end
	return copy
end

function env.get(name)
	assert(type(name) == "string", "name must be string", 2)
	return thisproc.env[name]
end

function env.set(name, value)
	assert(type(name) == "string", "name must be string", 2)
	assert(type(value) == "string" or value == nil, "value must be string or nil", 2)
	if string.find(name, "=") then
		return nil, "EINVAL", "environment variable name cannot contain '='"
	end

	thisproc.env[name] = value
	return true
end

function env.all()
	return shallowcopy(thisproc.env)
end

return env
