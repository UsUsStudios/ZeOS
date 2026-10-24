local event = {}

local function assert(v, msg, lvl)
	if not v then
		error(msg or "assertion failed!", lvl + 1)
	end
	return v
end

function event.pull(filter, timeout)
	assert(type(filter) == "string" or filter == nil, "filter must be string or nil", 2)
	assert(type(timeout) == "number" or timeout == nil, "timeout must be number or nil", 2)

	local event_queue = scheduler.running.event_queue

	if timeout and timeout < 0 then
		return nil, "EINVAL", "cannot sleep for a negative amount of time"
	end

	local endtime = chip.getTime() + (timeout or 0)
	while true do
		if endtime <= chip.getTime() and timeout then
			return
		end
		if #event_queue > 0 then
			local possible = table.remove(event_queue, 1)
			if filter == nil or possible[1] == filter then
				return table.unpack(possible)
			end
		end
		coroutine.yield()
	end
end

function event.poll()
	local event_queue = scheduler.running.event_queue

	if #event_queue > 0 then
		return table.unpack(table.remove(event_queue, 1))
	end
end

function event.push(name, ...)
	assert(type(name) == "string", "name must be string or nil", 2)

	table.insert(scheduler.running.event_queue, { name, ... })

	return true
end

function event.clear()
	scheduler.running.event_queue = {}
end

return event
