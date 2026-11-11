local _, ns = ...

-- Classic Era quest IDs stay below 10000. QuestieDB has no origin field in baked mode,
-- so every higher ID comes from the Forever data layer.
local FOREVER_MIN_ID = 10000
local DEFAULT_GREEN_RANGE = 8

-- Same values as the Blizzard QuestDifficultyColors table.
local COLORS = {
	impossible = "ff1919",
	veryDifficult = "ff8040",
	difficult = "ffff00",
	standard = "40c040",
	trivial = "808080",
}

ns.QuestLevel = { COLORS = COLORS }

function ns.QuestLevel.IsForever(id)
	return id >= FOREVER_MIN_ID
end

local function greenRange(env)
	if env.UnitQuestTrivialLevelRange then
		return env.UnitQuestTrivialLevelRange("player")
	elseif env.GetQuestGreenRange then
		return env.GetQuestGreenRange("player")
	end
	return DEFAULT_GREEN_RANGE
end

-- UnitLevel still returns the old level while PLAYER_LEVEL_UP runs, so the event level wins.
function ns.QuestLevel.Player(env, eventLevel)
	local level = eventLevel or (env.UnitLevel and env.UnitLevel("player"))
	if not level or level <= 0 then
		return nil
	end
	return { level = level, greenRange = greenRange(env) or DEFAULT_GREEN_RANGE }
end

function ns.QuestLevel.Difficulty(questLevel, player)
	local diff = questLevel - player.level
	if diff >= 5 then
		return "impossible"
	elseif diff >= 3 then
		return "veryDifficult"
	elseif diff >= -2 then
		return "difficult"
	elseif -diff <= player.greenRange then
		return "standard"
	end
	return "trivial"
end

-- QuestieDB stores 0 or a negative value for a quest that scales to the player level.
function ns.QuestLevel.Text(questLevel, player)
	if not questLevel or questLevel <= 0 then
		return ""
	end
	local text = ("[%d]"):format(questLevel)
	if not player then
		return text
	end
	return "|cff" .. COLORS[ns.QuestLevel.Difficulty(questLevel, player)] .. text .. "|r"
end
