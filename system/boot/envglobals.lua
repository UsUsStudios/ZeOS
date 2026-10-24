-- this file contains values that should be accessed globally by the APIs of all

_G.filelocks = {} -- dictionary of path : number of handles open on path
-- if zero, entry is removed

-- initialize _G.diskids and _G.diskids
if files.isFile("0:system:/boot/diskids") then
	local handle = files.open("0:system:/boot/diskids")
	local data = handle.read("a")
	handle.close()

	local function split(inputstr, sep)
		local t = {}
		for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
			table.insert(t, str)
		end
		return t
	end

	local pairs = split(data, "/")
	_G.diskids = {}
	for _, entry in ipairs(pairs) do
		local k, v = table.unpack(split(entry, ":"))
		_G.diskids[k] = v
	end
else
	_G.diskids = {}
	files.open("0:system:/boot/diskids", "a").close()
end
_G.attached_disks = { hdd = 0 }

_G.thisproc = nil -- the PCB of the process whose code is currently being run
