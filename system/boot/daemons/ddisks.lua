local function tablelength(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

local function serialize(t)
	local strbuf = {}
	for k, v in pairs(t) do
		table.insert(strbuf, k .. ":" .. v)
	end
	return table.concat(strbuf, "/")
end

while true do
	_G.attached_disks = {}
	for _, slot in ipairs(files.getDisks()) do
		local uuid = files.getDiskID(slot)
		if not _G.diskids[uuid] then
			_G.diskids[uuid] = "hdd" .. tablelength(_G.diskids)
		end

		_G.attached_disks[_G.diskids[uuid]] = slot
	end

	local handle = files.open("0:system:/boot/diskids", "w")
	handle.write(serialize(_G.diskids))
	handle.close()
	for _ = 1, 15 do
		coroutine.yield()
	end
end
