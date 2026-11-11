local _, ns = ...

local DUNGEONS = "Dungeons & Raids"
local OTHER = "Other"
local GOLD = "|cffffd100"
local GREY = "|cff9d9d9d"
local DONE_MARK = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14|t"
local MAX_PARENT_STEPS = 10

ns.OverviewModel = { DUNGEONS = DUNGEONS, OTHER = OTHER }

local function continentName(env, info)
	local UIMapType = env.Enum.UIMapType
	local current = info
	for _ = 1, MAX_PARENT_STEPS do
		if current.mapType == UIMapType.Continent then
			return current.name
		end
		if not current.parentMapID or current.parentMapID == 0 then
			return nil
		end
		current = env.C_Map.GetMapInfo(current.parentMapID)
		if not current then
			return nil
		end
	end
end

local function groupTitle(env, info)
	if not info then
		return OTHER
	end
	if info.mapType == env.Enum.UIMapType.Dungeon then
		return DUNGEONS
	end
	return continentName(env, info) or OTHER
end

local function mapName(env, index, uiMapID, info)
	if info and info.name then
		return info.name
	end
	local areaID = index:AreaFor(uiMapID)
	return (areaID and env.C_Map.GetAreaInfo(areaID)) or ("Map " .. uiMapID)
end

local function byName(a, b)
	local la, lb = a.name:lower(), b.name:lower()
	if la ~= lb then
		return la < lb
	end
	return a.id < b.id
end

local function titleRank(title)
	if title == DUNGEONS then
		return 1
	elseif title == OTHER then
		return 2
	end
	return 0
end

function ns.OverviewModel.Groups(env, index, state)
	local isDone = function(id)
		return state:IsDone(id)
	end
	local byTitle = {}
	for _, uiMapID in ipairs(index:Maps()) do
		local info = env.C_Map.GetMapInfo(uiMapID)
		local title = groupTitle(env, info)
		local done, total = ns.Progress.For(index, uiMapID, isDone)
		local group = byTitle[title]
		if not group then
			group = { title = title, maps = {} }
			byTitle[title] = group
		end
		table.insert(group.maps, {
			uiMapID = uiMapID,
			id = uiMapID,
			name = mapName(env, index, uiMapID, info),
			done = done,
			total = total,
			unknown = state:UnknownCount(uiMapID),
			complete = total > 0 and done == total,
		})
	end
	local groups = {}
	for _, group in pairs(byTitle) do
		table.sort(group.maps, byName)
		table.insert(groups, group)
	end
	table.sort(groups, function(a, b)
		local ra, rb = titleRank(a.title), titleRank(b.title)
		if ra ~= rb then
			return ra < rb
		end
		return a.title:lower() < b.title:lower()
	end)
	return groups
end

local TAG_ORDER = { { "class", "[Class]" }, { "profession", "[Profession]" }, { "race", "[Race]" } }

local function tagString(tags)
	local parts = {}
	for _, tag in ipairs(TAG_ORDER) do
		if tags[tag[1]] then
			table.insert(parts, tag[2])
		end
	end
	return table.concat(parts, " ")
end

function ns.OverviewModel.Quests(index, state, uiMapID, showNames)
	local doneRows, undoneRows = {}, {}
	for _, quest in ipairs(index:QuestsOn(uiMapID)) do
		local done = state:IsDone(quest.id) and true or false
		local name = quest.name or ("Quest " .. quest.id)
		local row = {
			id = quest.id,
			name = name,
			text = (done or showNames) and name or "???",
			done = done,
			tags = tagString(quest.tags),
		}
		table.insert(done and doneRows or undoneRows, row)
	end
	table.sort(doneRows, byName)
	table.sort(undoneRows, byName)
	for _, row in ipairs(undoneRows) do
		table.insert(doneRows, row)
	end
	return doneRows
end

function ns.OverviewModel.Message(index)
	index:Build()
	if index.error == "zonedata" then
		return "QuestieDB zone data not found"
	elseif index.error == "player" then
		return "Character data not available"
	end
end

function ns.OverviewModel.MapRowText(map)
	local text = ("%s  %d/%d"):format(map.name, map.done, map.total)
	if map.complete then
		text = GOLD .. text .. "|r"
	end
	if map.unknown > 0 then
		text = text .. "  " .. GREY .. ("+%d unknown"):format(map.unknown) .. "|r"
	end
	return text
end

function ns.OverviewModel.QuestRowText(row)
	local text = row.text
	if row.tags ~= "" then
		text = text .. "  " .. row.tags
	end
	if row.done then
		text = DONE_MARK .. " " .. text
	end
	return text
end
