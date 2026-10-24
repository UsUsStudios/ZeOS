local function assert(v, msg, lvl)
	if not v then
		error(msg or "assertion failed!", lvl + 1)
	end
	return v
end

-- read: (function("l" or "a" or number) -> string, or nil, or nil, err1, err2) or nil
-- write: (function(string or number) -> nil, or err1, err2) or nil
-- seek: (function(string, number) -> int, or nil, err1, err2) or nil
-- flush: (function() -> true, or nil, err1, err2) or nil
-- close: function() or nil
return function(read, write, seek, flush, close)
	local open = true
	local handle = {}
	if read then
		function handle:read(format)
			assert(open, "cannot read from closed handle", 2)
			if format ~= "l" or format == nil then
				return read("l")
			elseif format == "a" then
				return read("a")
			elseif type(format) == "number" and math.floor(format) == format then
				return read(format)
			end
			return nil, "EINVAL", "the format is not 'l', 'a' or an integer"
		end
	else
		function handle:read()
			return nil, "EBADF", "handle does not support reading"
		end
	end

	if write then
		function handle.write(...)
			assert(open, "cannot write to closed handle", 2)

			for _, bytes in ipairs({ ... }) do
				assert(type(bytes) == "string" or type(bytes) == "number", "argument must be string or number", 2)
				local err1, err2 = write(bytes)
				if err1 then
					return nil, err1, err2
				end
			end

			return handle
		end
	else
		function handle.write()
			return nil, "EBADF", "handle does not support writing"
		end
	end

	if seek then
		function handle.seek(whence, offset)
			assert(open, "cannot seek on closed handle", 2)

			if whence ~= "set" and whence ~= "cur" and whence ~= "end" then
				return nil, "EINVAL", "invalid whence"
			end

			return seek(whence, offset)
		end
	else
		function handle.seek()
			return nil, "ESPIPE", "handle does not support seeking"
		end
	end

	if flush then
		function handle.flush()
			assert(open, "cannot seek on closed handle", 2)

			return flush()
		end
	else
		function handle.flush()
			return true
		end
	end

	if close then
		function handle.close(...)
			assert(open, "cannot close already closed handle", 2)

			close()
			open = false
			return true
		end
	else
		function handle.close(...)
			return true
		end
	end
end
