return {
	["Config"] = {
		["DefaultEntry"] = 1, -- the option that appears highlighted first when entering the boot menu
		["Autoboot"] = "none", -- or: index number for .Bootlist[i]
	},
	["Bootlist"] = {
		{
			["OS Name"] = "ZeOS",
			["OS Version"] = "0.0.1",
			["OS Description"] = "NEATO-compatible NEET operating system",
			["OS Boot Path"] = "0:system:/boot/boot.lua",
		},
	},
}
