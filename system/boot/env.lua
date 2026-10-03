local g = {}

local function clone(t)
	local copy
	if type(t) == "table" then
		copy = {}
		for key, value in pairs(t) do
			copy[clone(key)] = clone(value)
		end
		setmetatable(copy, clone(getmetatable(t)))
	else
		copy = t
	end
	return copy
end

local function include(package)
	local handle = files.open("0:system:/boot/env/" .. package .. ".lua")
	local data = handle.read("a")
	handle.close()
	local f, err = load(data, "0:system:/boot/env/" .. package .. ".lua", nil, _G)
	if err then
		error(err)
	end
	if not f then
		error("function is nil")
	end
	return f()
end

-- lua single-function builtins
g._G = g
g.pairs = pairs
g.type = type
g.rawget = rawget
g.rawequal = rawequal
g.rawlen = rawlen
g.rawset = rawset
g.setmetatable = setmetatable
g.getmetatable = getmetatable
g.tostring = tostring
g.tonumber = tonumber
g.pcall = pcall
g.xpcall = xpcall
g.type = type
g.load = load
g.pairs = pairs
g.ipairs = ipairs
g.next = next
g.select = select
g.error = error
g.assert = assert
g.print = print -- TODO: TEMPORARY
g._VERSION = _VERSION

-- lua package builtins
g.utf8 = clone(utf8)
g.table = clone(table)
g.math = clone(math)
g.bit32 = clone(_G.bit32)
g.string = clone(string)
g.coroutine = clone(coroutine)

g.CWD = ...

-- neato-defined packages
g.sys = include("sys")
g.event = include("event")
g.crypto = clone(_G.crypto) -- WARNING: neetemu doesn't include crypto at the moment so this is nil

return g
