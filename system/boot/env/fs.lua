local fs = {}

local filelocks = {} -- dictionary of path : number of handles open on path
-- if zero, entry is removed

local fs_points = {
	["system.root"] = "0:system:/",
	["system.bin"] = "0:system:/bin/",
	["system.sbin"] = "0:system:/bin/",
	["system.libraries"] = "0:system:/lib/",
	["system.source"] = "0:system:/app/src/",
	["system.config"] = "0:system:/cfg/",
	["system.boot"] = "0:system:/boot/",
	["software.opt"] = "0:system:/app/",
	["software.opt.config"] = "0:system:/app/cfg/",
	["software.opt.data"] = "0:system:/app/data/",
	["software.local"] = "0:system:/app/",
	["software.localData"] = "0:system:/app/data/",
	["software.data"] = "0:system:/share/",
	["storage.persistent"] = "0:system:/var/",
	["storage.runtime"] = "0:system:/var/run/",
	["storage.state"] = "0:system:/app/cache/",
	["storage.cache"] = "0:system:/app/cache/",
	["storage.log"] = "0:system:/var/log/",
	["storage.spool"] = "0:system:/var/spool/",
	["storage.lock"] = "0:system:/var/lock/",
	["storage.mail"] = "0:system:/var/mail/",
	["storage.crash"] = "0:system:/var/crash/",
	["storage.games"] = "0:system:/app/data/",
	["storage.temporary"] = "0:system:/tmp/",
	["storage.temporaryPersistent"] = "0:system:/var/tmp",
	["user.home"] = "0:system:/usr/",
	["user.admin"] = "0:system:/usr/root/",
	["service.data"] = "0:system:/srv/",
}

local function split(inputstr, sep)
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

-- convert any NEATO path into an full NEATO path
local function resolvePath(path)
	local parts = split(path, ":")
	if #parts == 3 then
		return path
	elseif #parts == 1 then
		if string.sub(path, 1, 1) == "/" then
			local cwdparts = split(CWD, ":")
			if #cwdparts ~= 3 then
				error("invalid CWD", 3)
			end

			return table.concat({ cwdparts[1], cwdparts[2], path }, ":")
		else
			if string.sub(CWD, #CWD, #CWD) ~= "/" then
				CWD = CWD .. "/"
			end
			return CWD .. path
		end
	end

	error("invalid NEATO path format", 3)
end

-- walks along a path from a starting disk and partition, and returns a NEATO improved path
local function walk(disk, partition, filename)
	if not pcall(files.getPartitions, disk) then
		return nil, "ENODEV", "the disk slot " .. disk .. " is not occupied"
	end
	if not files.getPartition(partition, disk) then
		return nil, "ENOENT", "the " .. partition .. " partition does not exist on disk " .. disk
	end

	local path_segs = split(filename, "/")
	local final_segs = { disk .. ":" .. partition .. ":" }
	local concat_path = table.concat(final_segs, "/") .. "/"
	for i, seg in ipairs(path_segs) do
		if seg == "." then
		elseif seg == ".." then
			if #final_segs > 1 then
				final_segs[#final_segs] = nil
			end
		else
			final_segs[#final_segs + 1] = seg
			concat_path = table.concat(final_segs, "/")
			if not files.exists(concat_path) then
				return nil, "ENOENT", "The path '" .. concat_path .. "' does not exist."
			elseif files.isFile(concat_path) and i ~= #path_segs then
				return nil,
					"EISDIR",
					"The path '"
						.. concat_path
						.. "' references a file when a directory was expected in the full path '"
						.. final_segs[1]
						.. filename
						.. "'."
			end
		end
	end

	return concat_path
end
-- walks a full NEATO path, and returns the NEET path
-- will also check for permissions issues
local function walkNeatoPath(path, skiplast)
	local parts = split(path, ":")
	local disk, partition, filename = parts[1], parts[2], parts[3]

	if string.sub(filename, 1, 1) ~= "/" then
		error("filename portion of NEATO path must begin with a /", 3)
	end
	local last

	if skiplast then
		local filename_segs = split(filename, "/")
		last = filename_segs[#filename_segs]
		filename = "/" .. table.concat(filename_segs, "/", 1, #filename_segs - 1)
	end

	if disk == "any" then
		for _, checkdisk in ipairs(files.getDisks()) do
			if walk(checkdisk, partition, filename) then
				return partition .. ":" .. filename, checkdisk
			end
		end
		return nil, "ENOENT", "The path " .. partition .. ":" .. filename .. " does not exist at any attached disk"
	elseif tonumber(disk) == nil then
		local diskslot = _G.attached_disks[disk]
		if not diskslot then
			return nil, "ENODEV", "the disk ID '" .. disk .. "' is not connected"
		end
		local res, err1, err2 = walk(diskslot, partition, filename)
		if res then
			return res, last
		end
		return nil, err1, err2
	else
		local res, err1, err2 = walk(disk, partition, filename)
		if res then
			return res, last
		end
		return nil, err1, err2
	end
end

function fs.exists(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	return walkNeatoPath(path) ~= nil
end

function fs.isFile(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	path = walkNeatoPath(path)
	return path ~= nil and files.isFile(path)
end

function fs.isDir(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	path = walkNeatoPath(path)
	return path ~= nil and files.isDir(path)
end

function fs.list(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	local neetpath, err1, err2 = walkNeatoPath(path)
	if neetpath then
		if files.isFile(neetpath) then
			return nil, "ENOTDIR", "'" .. path .. "' refers to a file, not a directory"
		end
		return files.getChildren(neetpath)
	end
	return nil, err1, err2
end

function fs.makeDir(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	local neetpath, last, err2 = walkNeatoPath(path, true)
	if neetpath then
		if files.exists(neetpath .. "/" .. last) then
			return nil, "EEXIST", "'" .. path .. "' already exists"
		end
		local parts = split(path, ":")
		if files.getPartition(parts[2], parts[1]).readonly then
			return nil, "EROFS", "cannot write to read-only partition '" .. parts[1] .. ":" .. parts[2] .. "'"
		end
		files.makeDir(neetpath .. "/" .. last)
		return true
	end
	return nil, neetpath, err2
end

function fs.delete(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	local neetpath, err1, err2 = walkNeatoPath(path)
	if neetpath then
		if #files.getChildren(neetpath) > 0 then
			return nil, "ENOTEMPTY", "directory '" .. path .. "' is not empty"
		end
		local parts = split(path, ":")
		if parts[3] == "/" then
			return nil, "EPERM", "cannot delete partition root '" .. path .. "'"
		elseif files.getPartition(parts[2], parts[1]).readonly then
			return nil, "EROFS", "cannot delete from read-only partition '" .. parts[1] .. ":" .. parts[2] .. "'"
		elseif filelocks[neetpath] then
			return nil, "EBUSY", "path is in use"
		end
		files.delete(neetpath)
		return true
	end
	return nil, err1, err2, path
end

function fs.open(path, mode)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	local handle
	if mode == "r" or mode == "rb" then
		local neetpath, err1, err2 = walkNeatoPath(path)
		if not neetpath then
			return nil, err1, err2
		elseif files.isDir(neetpath) then
			return nil, "EISDIR", "path '" .. neetpath .. "' refers to a directory"
		end
		handle = files.open(neetpath, "r")
	elseif mode ~= "a" and mode ~= "ab" and mode ~= "w" and mode ~= "wb" then
		return nil, "EINVAL", "the mode '" .. tostring(mode) .. "' is not valid"
	else
		local neetpath, last, err2 = walkNeatoPath(path, true)
		if neetpath then
			local parts = split(path, ":")
			if files.getPartition(parts[2], parts[1]).readonly then
				return nil, "EROFS", "cannot write to read-only partition '" .. parts[1] .. ":" .. parts[2] .. "'"
			elseif not files.isFile(neetpath .. last) then
				files.open(neetpath .. last, "a").close()
			end
		else
			return nil, last, err2
		end
	end

	local neetpath, err1, err2 = walkNeatoPath(path)
	if mode == "w" or mode == "wb" then
		if not neetpath then
			return nil, err1, err2
		end
		handle = files.open(neetpath, "w")
	elseif mode == "a" or mode == "ab" then
		if not neetpath then
			return nil, err1, err2
		end
		handle = files.open(neetpath, "a")
	end

	if not neetpath then
		return nil, err1, err2
	end

	-- update filelocks
	if filelocks[neetpath] then
		filelocks[neetpath] = filelocks[neetpath] + 1
	else
		filelocks[neetpath] = 1
	end
	return {
		open = true,
		read = function(self, format)
			assert(self.open, "cannot read from closed handle")
			if mode ~= "r" and mode ~= "rb" then
				return nil, "EBADF", "handle was opened for writing"
			elseif format == "l" or format == nil then
				return handle.read("l")
			elseif format == "a" then
				return handle.read("a")
			elseif type(format) == "number" and math.floor(format) == format then
				return handle.read(format)
			end
			return nil, "EINVAL", "the format is not 'l', 'a' or an integer"
		end,
		write = function(self, ...)
			assert(self.open, "cannot write to closed handle")
			if mode == "r" or mode == "rb" then
				return nil, "EBADF", "handle was opened for reading"
			end

			for _, bytes in ipairs({ ... }) do
				assert(type(bytes) == "string" or type(bytes) == "number", "argument must be string or number")
				handle.write(bytes)
			end
		end,
		seek = function(self, whence, offset)
			assert(self.open, "cannot seek on closed handle")
			if whence ~= "set" and whence ~= "cur" and whence ~= "end" then
				return nil, "EINVAL", "invalid whence"
			end
			return handle.seek(whence, offset)
		end,
		flush = function(self)
			assert(self.open, "cannot flush closed handle")
			handle.flush()
		end,
		close = function(self)
			assert(self.open, "cannot close already closed handle")
			handle.close()
			self.open = false

			-- update filelocks
			filelocks[neetpath] = filelocks[neetpath] - 1
			if filelocks[neetpath] == 0 then
				filelocks[neetpath] = nil
			end
		end,
	}
end

function fs.resolve(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	return resolvePath(path)
end

function fs.rename(old, new)
	if type(old) ~= "string" then
		error("old must be string", 2)
	end
	if type(new) ~= "string" then
		error("new must be string", 2)
	end

	local oldpath, err1, err2 = walkNeatoPath(old)
	if not oldpath then
		return nil, err1, err2
	end
	local newpath, last, err3 = walkNeatoPath(new)
	if not newpath then
		return nil, last, err3
	end
	newpath = newpath .. last

	-- WARNING: temporary, until redtoast adds rename function to files API
	local oldh = fs.open(oldpath, "r")
	local newh = fs.open(newpath, "w")
	assert(oldh and newh)
	newh:write(oldh:read("a"))
	oldh:close()
	newh:close()
end

fs.rename("0:system:/hi", "0:system:/hello")

function fs.stat(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	local neetpath, err1, err2 = walkNeatoPath(path)

	if neetpath then
		local h = files.open(neetpath, "r")
		local size = h.seek("end", -1)
		return { type = files.isFile(neetpath) and "file" or "dir", size = size }
	end
	return nil, err1, err2
end

function fs.getDisks()
	local disks = {}
	for disk, slot in pairs(_G.attached_disks) do
		disks[#disks + 1] = { slot = slot, id = disk }
	end
	return disks
end

function fs.getPartitions(disk)
	if type(disk) == "number" then
		if math.floor(disk) ~= disk then
			error("version must be an integer", 2)
		end
	else
		if type(disk) ~= "string" then
			error("disk must be string or integer", 2)
		end
	end

	if not pcall(files.getPartitions, disk) then
		return nil, "ENODEV", "the disk slot " .. disk .. " is not occupied"
	end
	return files.getPartitions()
end

function fs.getPoint(point)
	if type(point) ~= "string" then
		error("point must be string", 2)
	end

	return fs_points[point]
end

local function shallowcopy(t)
	local copy = {}
	for key, value in pairs(t) do
		copy[key] = value
	end
	return copy
end

function fs.getPoints()
	return shallowcopy(fs_points)
end

return fs
