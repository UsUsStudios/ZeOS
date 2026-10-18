local function dump_table(name, indent, t)
	if name then
		print(name)
	end
	for k, v in pairs(t) do
		if type(v) == "table" and k ~= "_G" then
			print(indent .. k)
			dump_table(false, indent .. "    ", v)
		else
			print(indent .. k, v)
		end
	end
end

--print("IMPORTANT PACKAGES DUMP")
--dump_table("sys", "    ", _G.sys)
--dump_table("event", "    ", _G.event)
--print()
--print("dump complete")
--print()
