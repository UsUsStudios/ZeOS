local function add_event(event)
	for _, pcb in pairs(scheduler.processes) do
		table.insert(pcb.event_queue, event)
	end
end

-- TODO: make all the other keys accepted
local keymap = {
	[13] = "enter",
	[8] = "backspace",
	[9] = "tab",
	[32] = "space",
	[128] = "left",
	[129] = "right",
	[130] = "up",
	[131] = "down",
	[134] = "f1",
	[135] = "f2",
	[136] = "f3",
	[137] = "f4",
	[138] = "f5",
	[139] = "f6",
	[140] = "f7",
	[141] = "f8",
	[142] = "f9",
	[143] = "f10",
	[144] = "f11",
	[145] = "f12",
}

local e
while true do
	e = event.getFirst("User")
	while e do
		if e[1] == "keyPressed" then
			if e[3] ~= "" and e[3] ~= " " then
				add_event({ "key", e[3], false }) -- TODO: make the repeating boolean accurate
				add_event({ "char", e[3] })
			elseif keymap[e[2]] then
				add_event({ "key", keymap[e[2]], false }) -- TODO: make the repeating boolean accurate
			end
		elseif e[1] == "keyReleased" then
			add_event({ "keyUp", e[3] })
		end
		e = event.getFirst("User")
	end
	coroutine.yield()
end
