local h = files.open("system:/boot/kernel.lua", "r", 0)
local data = h.read("a")
h.close()
load(data, "KERNEL:kernel.lua")()
