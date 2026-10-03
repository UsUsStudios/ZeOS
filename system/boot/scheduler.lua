_G.scheduler = {}

local wrap_process = include("errors.lua")()

scheduler.pid_counter = 0
scheduler.processes = {}
scheduler.time_period = 0.05 -- in seconds
scheduler.cpu_load = 0 -- in a percentage
scheduler.loads = {}
scheduler.ticks = 0
scheduler.running = nil -- the PCB of the process whose code is currently being run

local ready_queue = {} -- the list of pids that should be run next tick

function scheduler.queue(pcb)
	pcb.state = "ready"
	table.insert(ready_queue, pcb.pid)
end

-- create a new process running the function fn with an optional parent pid and args
function scheduler.new_process(fn, args)
	if fn == nil then
		error("cannot start process with function nil")
	end

	scheduler.pid_counter = scheduler.pid_counter + 1
	local pcb = {
		pid = scheduler.pid_counter,
		state = "ready", -- ready | running | zombie | dead
		exit_code = nil,
		error = nil, -- the error that the process exited with
		yields = 0, -- how many yields have been processed by the scheduler
		utime = 0, -- how many seconds has the CPU spent running this process's code
		event_queue = {}, -- per-process infinite event queue
	}
	pcb.co = coroutine.create(function()
		wrap_process(fn, pcb, table.unpack(args or {}))
	end)
	debug.sethook(pcb.co, function()
		if coroutine.isyieldable() then
			coroutine.yield()
		end
	end, "", 500)

	scheduler.processes[pcb.pid] = pcb
	scheduler.queue(pcb)

	return pcb
end

-- sends some messages when a process dies
function scheduler.dead(pcb, msg, req)
	if not pcb.exit_code then
		pcb.exit_code = -1
	end
	print("Process with PID " .. pcb.pid .. " ended with exit code " .. pcb.exit_code)
	if type(req) ~= "table" and req then
		print("    error of exit: " .. msg .. req)
	else
		print("    " .. msg)
	end
end

local gettime = chip.getTime
function scheduler.tick()
	scheduler.ticks = scheduler.ticks + 1

	local queue = ready_queue
	ready_queue = {}

	for _, pid in ipairs(queue) do
		local pcb = scheduler.processes[pid]
		if pcb and pcb.state == "ready" then
			local start = gettime()
			pcb.state = "running"
			scheduler.running = pcb
			local ok, err, code = coroutine.resume(pcb.co)
			scheduler.running = nil
			pcb.error = err

			if pcb.state == "running" then -- if no system function changed its state
				scheduler.queue(pcb)
			end

			if coroutine.status(pcb.co) == "dead" then
				pcb.state = "zombie"
				pcb.exit_code = pcb.exit_code or 0

				scheduler.dead(pcb, "coroutine found dead")
			elseif not ok or code == "error" then
				-- uncaught error
				pcb.state = "zombie"
				pcb.exit_code = -1

				scheduler.dead(pcb, "uncaught error, ", err)
			end

			local utime = gettime() - start
			pcb.utime = pcb.utime + utime
			scheduler.loads[pid] = utime / scheduler.time_period * 100
		end
	end
end
