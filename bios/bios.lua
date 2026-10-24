-- written by SPSF, 2026, licensed under 2-clause BSD License

local W, H = screen.getSize()

local function loadFont(slot, part, path)
	local ok, h = pcall(files.open, part .. ":" .. path, "rb", slot)
	if not ok or not h then
		return nil
	end
	local data = h.read("a")
	h.close()
	if not data or #data < 4 then
		return nil
	end
	local glyphs, gw, gh = {}, 8, 0
	local b1, b2 = data:byte(1, 2)
	if b1 == 0x36 and b2 == 0x04 then
		local mode, size = data:byte(3, 4)
		gh = size
		local n = (mode % 4 >= 2) and 512 or 256
		for i = 0, n - 1 do
			local off = 4 + i * size
			if off + size > #data then
				break
			end
			glyphs[i] = data:sub(off + 1, off + size)
		end
	elseif b1 == 0x72 and b2 == 0xb5 then
		local _, headersize, _, num, bpg, h2, w2 = string.unpack("<I4I4I4I4I4I4I4", data, 5)
		gw, gh = w2, h2
		for i = 0, num - 1 do
			local off = headersize + i * bpg
			if off + bpg > #data then
				break
			end
			glyphs[i] = data:sub(off + 1, off + bpg)
		end
	else
		return nil
	end
	return { glyphs = glyphs, w = gw, h = gh, bpr = (gw + 7) // 8, cache = {} }
end

local function drawText(font, x, y, text, r, g, b)
	if not font then
		return
	end
	local on, off = string.char(r, g, b, 255), "\0\0\0\255"
	for i = 1, #text do
		local code = text:byte(i)
		local key = code * 16777216 + r * 65536 + g * 256 + b
		local buf = font.cache[key]
		if not buf then
			local gl = font.glyphs[code] or font.glyphs[63]
			local px, n = {}, 0
			for yy = 0, font.h - 1 do
				for xx = 0, font.w - 1 do
					local byte = gl and gl:byte(yy * font.bpr + (xx // 8) + 1) or 0
					n = n + 1
					px[n] = ((byte >> (7 - xx % 8)) & 1) == 1 and on or off
				end
			end
			buf = table.concat(px)
			font.cache[key] = buf
		end
		screen.writeData(x, y, buf, font.w)
		x = x + font.w
	end
end

local function diskList()
	local out = {}
	local ok, raw = pcall(files.getDisks)
	if not ok or type(raw) ~= "table" then
		return out
	end
	for _, d in ipairs(raw) do
		local slot = type(d) == "table" and (d.slot or d[1]) or d
		local okid, id = pcall(files.getDiskID, slot)
		out[#out + 1] = { slot = slot, id = okid and id or tostring(slot) }
	end
	table.sort(out, function(a, b)
		return a.slot < b.slot
	end)
	return out
end

local function hasPartition(slot, name)
	local ok, parts = pcall(files.getPartitions, slot)
	if not ok or type(parts) ~= "table" then
		return false
	end
	for _, p in ipairs(parts) do
		if (type(p) == "table" and p.name or p) == name then
			return true
		end
	end
	return false
end

local function splitFull(path)
	local d, p, f = tostring(path):match("^([^:]+):([^:/]+):(/.*)$")
	if not d then
		return nil, "not a full path: " .. tostring(path)
	end
	local disks = diskList()
	if d == "any" then
		for _, disk in ipairs(disks) do
			if hasPartition(disk.slot, p) then
				return disk.slot, p, f
			end
		end
		return nil, "no disk has partition '" .. p .. "'"
	end
	for _, disk in ipairs(disks) do
		if disk.id == d or (d:match("^%d+$") and disk.slot == tonumber(d)) then
			return disk.slot, p, f
		end
	end
	return nil, "no such disk: " .. d
end

local function readFile(path)
	local slot, part, fp = splitFull(path)
	if not slot then
		return nil, part
	end
	local ok, h = pcall(files.open, part .. ":" .. fp, "r", slot)
	if not ok or not h then
		return nil, "cannot open " .. path
	end
	local data = h.read("a")
	h.close()
	return data or ""
end

local CFG_PATH = "any:system:/boot/cfg/boot.lua"

local function validEntry(e)
	if type(e) ~= "table" then
		return false
	end
	if type(e["OS Name"]) ~= "string" or type(e["OS Boot Path"]) ~= "string" then
		return false
	end
	if e["OS Version"] ~= nil and type(e["OS Version"]) ~= "string" then
		return false
	end
	if e["OS Description"] ~= nil and type(e["OS Description"]) ~= "string" then
		return false
	end
	if e["OS Args"] ~= nil and type(e["OS Args"]) ~= "table" then
		return false
	end
	if e["OS Environment Variable Definition"] ~= nil and type(e["OS Environment Variable Definition"]) ~= "table" then
		return false
	end
	return true
end

local function loadConfig()
	local src, err = readFile(CFG_PATH)
	if not src then
		return nil, err
	end
	local chunk, cerr = load(src, "=boot.lua", "t", {})
	if not chunk then
		return nil, cerr
	end
	local ok, cfg = pcall(chunk)
	if not ok or type(cfg) ~= "table" then
		return nil, "boot.lua did not return a table"
	end
	return cfg
end

local function boot(entry)
	local src, err = readFile(entry["OS Boot Path"])
	if not src then
		error("boot failed: " .. tostring(err), 0)
	end
	local chunk, cerr = load(src, "=" .. entry["OS Boot Path"])
	if not chunk then
		error("boot failed: " .. tostring(cerr), 0)
	end
	local env = {}
	for k, v in pairs(entry["OS Environment Variable Definition"] or {}) do
		env[k] = v
	end
	_G.ENV = env
	local args = entry["OS Args"] or {}
	return chunk(table.unpack(args))
end

local function menu(cfg, list)
	local font = loadFont(0, "bios", "/assets/default8x9.psf") or loadFont(0, "xes", "/usr/share/fonts/default8x9.psf")
	local sel = tonumber(cfg.Config and cfg.Config.DefaultEntry) or 1
	if sel < 1 or sel > #list then
		sel = 1
	end
	local function paint()
		screen.fill(0, 0, W - 1, H - 1, 0, 0, 0, 255)
		drawText(font, 8, 8, "NEATO bootloader", 240, 240, 240)
		drawText(font, 8, 20, "Select an operating system (up/down, enter):", 153, 153, 153)
		for i, e in ipairs(list) do
			local y = 44 + (i - 1) * 24
			local on = i == sel
			drawText(
				font,
				16,
				y,
				(on and "> " or "  ") .. e["OS Name"] .. (e["OS Version"] and (" " .. e["OS Version"]) or ""),
				on and 127 or 200,
				on and 204 or 200,
				on and 25 or 200
			)
			if e["OS Description"] then
				drawText(font, 40, y + 11, e["OS Description"], 110, 110, 110)
			end
		end
		screen.draw()
	end
	paint()
	while true do
		local dirty = false
		for _, ev in ipairs(event.getQueue("User")) do
			if ev[1] == "keyPressed" then
				if ev[2] == 130 then
					sel = (sel - 2) % #list + 1
					dirty = true
				elseif ev[2] == 131 then
					sel = sel % #list + 1
					dirty = true
				elseif ev[2] == 13 then
					return list[sel]
				end
			end
		end
		if dirty then
			paint()
		end
		coroutine.yield()
	end
end

local cfg, err = loadConfig()
if not cfg then
	chip.crash("NEATO bootloader: cannot read " .. CFG_PATH .. ": " .. tostring(err))
	return
end
local list = {}
for _, e in ipairs(cfg.Bootlist or {}) do
	if validEntry(e) then
		list[#list + 1] = e
	end
end
if #list == 0 then
	chip.crash("NEATO bootloader: no valid boot entries")
	return
end

local auto = cfg.Config and cfg.Config.Autoboot
local entry
if type(auto) == "number" and cfg.Bootlist[auto] and validEntry(cfg.Bootlist[auto]) then
	entry = cfg.Bootlist[auto]
else
	entry = menu(cfg, list)
end
boot(entry)
