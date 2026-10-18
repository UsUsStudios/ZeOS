local fs = {}

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
	for i, seg in ipairs(path_segs) do
		if seg == "." then
		elseif seg == ".." then
			if #final_segs > 1 then
				final_segs[#final_segs] = nil
			end
		else
			final_segs[#final_segs + 1] = seg
			local concat_path = table.concat(final_segs, "/")
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

	return table.concat(final_segs, "/")
end
-- walks a full NEATO path, and returns the NEET path
-- will also check for permissions issues
local function walkNeatoPath(path)
	local parts = split(path, ":")
	local disk, partition, filename = parts[1], parts[2], parts[3]
	if string.sub(filename, 1, 1) ~= "/" then
		error("filename portion of NEATO path must begin with a /")
	end

	if disk == "any" then
		for _, checkdisk in ipairs(files.getDisks()) do
			if walk(checkdisk, partition, filename) then
				return partition .. ":" .. filename, checkdisk
			end
		end
		return nil, "ENOENT", "The path " .. partition .. ":" .. filename .. " does not exist at any attached disk"
	else
		return walk(disk, partition, filename)
	end
end

function fs.exists(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end

	return
end

function fs.isFile(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end
	return
end

function fs.isDir(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end
	return
end

function fs.list(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end
	return
end

function fs.makeDir(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end
	return
end

function fs.delete(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end
	return
end

function fs.open(path, mode)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end
	return
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
	return
end

function fs.stat(path)
	if type(path) ~= "string" then
		error("path must be string", 2)
	end
	return
end

function fs.getDisks()
	return
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

	return
end

function fs.getPoint(point)
	if type(point) ~= "string" then
		error("point must be string", 2)
	end
	return
end

function fs.getPoints()
	return
end

return fs
