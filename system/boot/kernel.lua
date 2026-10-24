_G.screen.set()
_G.screen.draw()
_G.OS_NAME = "ZeOS"
_G.OS_VERSION = "v0.0.1"

function _G.include(path, env)
	local handle = files.open("0:system:/boot/" .. path)
	local data = handle.read("a")
	handle.close()
	local f, err = load(data, "KERNEL:" .. path, nil, env or _G)
	if err then
		error(err)
	end
	return f
end

function _G.panic(cause, msg)
	print()
	print("####################################################")
	print("################### KERNEL PANIC ###################")
	print("####################################################")
	print("Cause: " .. cause)
	print(msg)
	chip.shutdown()
end

do
	local handle = files.open("system:/boot/files-shim.lua")
	local data = handle.read("a")
	handle.close()
	local f, err = load(data, "KERNEL:files-shim.lua", nil, _G)
	if err or not f then
		error(err)
	end
	f()
end

include("scheduler.lua")()
include("envglobals.lua")()
local generate_env = include("env.lua")

local function execute(path, cwd, env, nohook)
	local handle = files.open(path)
	local data = handle.read("a")
	handle.close()
	if not env then
		env = generate_env(cwd)
	else
		env["CWD"] = cwd
	end

	local f, err = load(data, path, nil, env)
	if err or not f then
		panic("unable to open " .. path, err)
	end
	scheduler.new_process(f, nil, nil, nohook)
end

scheduler.new_process(function()
	execute("0:system:/boot/daemons/ddisks.lua", "0:system:/", _G, true)
	execute("0:system:/boot/daemons/devent.lua", "0:system:/", _G, true)
	execute("0:system:/init.lua", "0:system:/boot")
	while true do
		coroutine.yield()
	end
end)

local gettime = chip.getUnixTime
local loads = scheduler.loads
local pid1 = scheduler.processes[1]

while true do
	local last_time = gettime()

	scheduler.tick()
	local start = gettime()
	local ticking_time = gettime() - last_time
	if pid1.state ~= "ready" then
		panic("pid 1 is dead", "exit code: " .. tostring(pid1.exit_code) .. "\nerror: " .. tostring(pid1.error))
	end
	scheduler.cpu_load = ticking_time / scheduler.time_period * 100

	-- wait until the next tick is scheduled
	while last_time + scheduler.time_period > gettime() do
		coroutine.yield()
	end
	loads.idle = (gettime() - start) / scheduler.time_period * 100
end
