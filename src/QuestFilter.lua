local _, ns = ...

-- Flag values from QuestieDB src/corrections/enum/quests.lua. They are not public API, so they stay local.
local DAILY = 4096
local WEEKLY = 32768
local MONTHLY = 65536
local REPEATABLE = 1

local Bits = ns.Bits

ns.QuestFilter = {}

function ns.QuestFilter.Player(env)
	local enum = env.LibQuestieDB.Enum
	local raceID = select(3, env.UnitRace("player"))
	local faction = env.UnitFactionGroup("player")
	local classToken = select(2, env.UnitClass("player"))
	if classToken == "DEATHKNIGHT" then
		classToken = "DEATH_KNIGHT"
	end
	local raceMask = raceID and enum.raceMaskById[raceID]
	local factionMask = faction and enum.factionRaceMasks[faction]
	local classMask = classToken and enum.classKeys[classToken]
	if not (raceMask and factionMask and classMask) then
		return nil
	end
	return { raceMask = raceMask, factionMask = factionMask, classMask = classMask }
end

function ns.QuestFilter.Evaluate(row, player, allClasses)
	if not row or row.zoneOrSort <= 0 then
		return false
	end
	local races, classes = row.requiredRaces, row.requiredClasses
	if races ~= 0 and not Bits.Has(races, player.raceMask) then
		return false
	end
	if classes ~= 0 and not Bits.Has(classes, player.classMask) then
		return false
	end
	if Bits.Has(row.specialFlags, REPEATABLE) then
		return false
	end
	local flags = row.questFlags
	if Bits.Has(flags, DAILY) or Bits.Has(flags, WEEKLY) or Bits.Has(flags, MONTHLY) then
		return false
	end

	local tags = {}
	if classes ~= 0 and classes ~= allClasses then
		tags.class = true
	end
	if row.requiredSkill and row.requiredSkill[1] ~= 0 then
		tags.profession = true
	end
	if races ~= 0 and not Bits.HasAll(races, player.factionMask) then
		tags.race = true
	end
	return true, tags
end
