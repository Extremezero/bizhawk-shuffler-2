local plugin = {}

plugin.name = "Fighting Game Hit Shuffler"
plugin.author = "authorblues, kalimag, Extreme0"
plugin.settings = {}
plugin.description =
[[
	Automatically swaps games any time Player 1 gets hit before & after a combo. Checks hashes of different rom versions, so if you use a version of the rom that isn't recognized, nothing special will happen in that game (no swap on hit).

	Supports:
	-Capcom vs SNK Pro (USA)(PSX)
	-Killer Instinct (USA)(SNES)
	-Primal Rage (USA)(SNES)
	-Darkstalkers 3 (USA)(PSX)
	-Tekken 3 (USA)(PSX)
	-JoJo's Bizzare Adventure (USA)(PSX)
	-Psychic Force 2 (Japan)(PSX)
	-Street Fighter Alpha (USA)(PSX)
	-Street Fighter Alpha 2 (USA)(PSX)
	-Street Fighter Alpha 2 Gold* (USA)(PSX)
	-Street Fighter Alpha 3 (USA)(PSX)
	-Street Fighter EX2+ (JP)(USA)(PSX)
	-Street Fighter III: 4rd Strike Hack (Japan)(NO CD)(Not Recommended)**

	*Part of Street Fighter Collection Disc 2
	**CPS3 Arcade Games loading between swaps is too long to be fluid and near instant
]]

local NO_MATCH = 'NONE'

local prevdata
local swap_scheduled
local shouldSwap

-- optionally load BizHawk 2.9 compat helper to get rid of bit operator warnings
local bit = bit
if compare_version("2.9") >= 0 then
	local success, migration_helpers = pcall(require, "migration_helpers")
	bit = success and migration_helpers.EmuHawk_pre_2_9_bit and migration_helpers.EmuHawk_pre_2_9_bit() or bit
end


-- update value in prevdata and return whether the value has changed, new value, and old value
-- value is only considered changed if it wasn't nil before
local function update_prev(key, value)
	local prev_value = prevdata[key]
	prevdata[key] = value
	local changed = prev_value ~= nil and value ~= prev_value
	return changed, value, prev_value
end

local function hitstun_swap(gamemeta)
	return function(data)
	-- To be used when address value registers a single hit example: value of 1 = 1 hit ingame.

		local hitindicator = gamemeta.hitstun() --Thanks Kalimag

		local previoushit = data.hitstun
		data.hitstun = hitindicator

		if hitindicator == 1 and hitindicator ~= previoushit then
			return true 
			else
			return false
		end
	end
end

local function grab_swap(gamemeta)
	return function(data)
	-- To be used when grab needs a seperate address registered to activate the swap

		local hitindicator = gamemeta.hitstun() --Thanks Kalimag
		local previoushit = data.hitstun

		local grabindicator = gamemeta.grabbed()
		local previousgrab = data.grabbed

		data.hitstun = hitindicator
		data.grabbed = grabindicator

		if hitindicator == 1 and hitindicator ~= previoushit then
			return true 
			elseif grabindicator >= 1 and grabindicator ~= previousgrab then
			return true
			else
			return false
		end
	end
end

local function sf2_swap(gamemeta) --needs fixed. (Lua:103: attempt to compare number with nil)
	return function(data)

		local hitindicator = gamemeta.hitstun()
		local previoushit = data.hitstun

		local comboindicator = gamemeta.comboed()
		local previouscombo = data.comboed

		data.hitstun = hitindicator
		data.comboed = comboindicator

	
		if hitindicator == 1 and comboed == 0 then
			return true
			else
			return false
		end
	end
end

local gamedata = {
	['SSF2']={ -- Super Street Fighter 2 SNES USA
		hitstun=function() return memory.read_u8(0x0594, "WRAM") end,
		comboed=function() return memory.read_u8(0x0681, "WRAM") end,
		func=sf2_swap
	},
	['SFA']={ -- Street Fighter Alpha USA PSX
		hitstun=function() return memory.read_u8(0x187123, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x1873E2, "MainRAM") end,
		func=grab_swap
	},
	['SFA2']={ -- Street Fighter Alpha 2 USA PSX
		hitstun=function() return memory.read_u8(0x1981FE, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x19859B, "MainRAM") end,
		func=grab_swap
	},
	['SFA2G']={ -- Street Fighter Alpha 2 Gold USA PSX
		hitstun=function() return memory.read_u8(0x197622, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x18F19B, "MainRAM") end,
		func=grab_swap
	},
	['SFA3']={ --Street Fighter Alpha 3 USA PSX
		hitstun=function() return memory.read_u8(0x19D019, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x1944AF, "MainRAM") end,
		func=grab_swap
	},
	['DS3']={ --Darkstalkers 3 USA PSX
		hitstun=function() return memory.read_u8(0x1C0F00, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x1C12C8, "MainRAM") end,
		func=grab_swap
	},
	['Tekken3']={ --Tekken 3 USA PSX
		hitstun=function() return memory.read_u8(0x0A92A8, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x0AAB28, "MainRAM") end,
		func=grab_swap
	},
	['JoJo']={ --JoJo's Bizzare Adventure USA PSX
		hitstun=function() return memory.read_u8(0x0CDAC6, "MainRAM") end,
		grabbed=function() return memory.read_u8(0x0CD75A, "MainRAM") end,
		func=grab_swap
	},
	['PsyForce2']={ --Psychic Force 2 Japan PSX
		hitstun=function() return memory.read_u8(0x0D3EE8, "MainRAM") end,
	},
	['SFEX2PlusJP']={ --Street Fighter EX 2 Plus Japan PSX
		hitstun=function() return memory.read_u8(0x1E9210, "MainRAM") end,
	},
	['SFEX2PlusUSA']={ --Street Fighter EX 2 Plus USA PSX
		hitstun=function() return memory.read_u8(0x1E9788, "MainRAM") end,
	},
	['SFIII:4rdStrike']={ --Street Fighter III: 4rd Strike Hack (Japan)(NO CD)(Arcade)
		hitstun=function() return memory.read_u8(0x06961D, "sh2 : ram : 0x2000000-0x207FFFF") end,
	},
	['KISNES']={ --Killer Instinct SNES USA
		hitstun=function() return memory.read_u8(0x0DE8, "WRAM") end,
	},
	['PrimalRageSNES']={ --Primal Rage SNES USA
		hitstun=function() return memory.read_u8(0x1C94, "WRAM") end,
	},
	['CVSProPSX']={ -- Capcom VS SNK Pro USA PSX
		hitstun=function() return memory.read_u8(0x06E6B3, "MainRAM") end,
	},

}

local function get_game_tag()
	-- try to just match the rom hash first
	local tag = get_tag_from_hash_db(gameinfo.getromhash(), 'plugins/fighting-hashes.dat')
	if tag ~= nil and gamedata[tag] ~= nil then return tag end

	-- check to see if any of the rom name samples match
	local name = gameinfo.getromname()
	for _,check in pairs(backupchecks) do
		if check.test() then return check.tag end
	end

	return nil
end

function plugin.on_setup(data, settings)
	data.tags = data.tags or {}
end

function plugin.on_game_load(data, settings)
	prevdata = {}
	swap_scheduled = false
	shouldSwap = function() return false end

	local tag = data.tags[gameinfo.getromhash()] or get_game_tag()
	data.tags[gameinfo.getromhash()] = tag or NO_MATCH

	-- first time through with a bad match, tag will be nil
	-- can use this to print a debug message only the first time
	if tag ~= nil and tag ~= NO_MATCH then
		log_message('game match: ' .. tag)
		local gamemeta = gamedata[tag]
		local func = gamemeta.func or hitstun_swap
		shouldSwap = func(gamemeta)
	elseif tag == nil then
		log_message(string.format('unrecognized? %s (%s)',
			gameinfo.getromname(), gameinfo.getromhash()))
	end
end

function plugin.on_frame(data, settings)
	-- run the check method for each individual game
	if swap_scheduled then return end

	local schedule_swap, delay = shouldSwap(prevdata)
	if schedule_swap and frames_since_restart > 10 then
		swap_game_delay(delay or 3)
		swap_scheduled = true
	end
end

return plugin