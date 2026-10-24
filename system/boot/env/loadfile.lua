function _G.loadfile(filename, mode, env)
	local handle, err1, err2 = fs.open(filename, "r")
	if not handle then
		error(err1 .. ":" .. err2)
	end

	local data = handle:read("a")
	handle:close()

	-- I /think/ using `_G` as the default value is the right thing to
	-- do here? I'm not completely sure about that, though.
	return load(data, filename, mode or "bt", env or _G)
end
