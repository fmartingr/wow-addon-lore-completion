local _, ns = ...

local L = ns.L
local DUNGEONS = L["Dungeons & Raids"]
local OTHER = L["Other"]
local GOLD = "|cffffd100"
local GREY = "|cff9d9d9d"
local MAX_PARENT_STEPS = 10
local FOREVER_ICON = "|TInterface\\AddOns\\LoreCompletion\\assets\\forever.tga:14:14|t"
local PIN_ICON = "|TInterface\\AddOns\\LoreCompletion\\assets\\giver.tga:14:14|t"

ns.OverviewModel = { DUNGEONS = DUNGEONS, OTHER = OTHER, FOREVER_ICON = FOREVER_ICON, PIN_ICON = PIN_ICON }

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
	return (areaID and env.C_Map.GetAreaInfo(areaID)) or L["Map %d"]:format(uiMapID)
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
			group = { title = title, maps = {}, done = 0, total = 0 }
			byTitle[title] = group
		end
		group.done = group.done + done
		group.total = group.total + total
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

local TAG_ORDER = { { "class", L["[Class]"] }, { "profession", L["[Profession]"] }, { "race", L["[Race]"] } }

local function tagString(tags)
	local parts = {}
	for _, tag in ipairs(TAG_ORDER) do
		if tags[tag[1]] then
			table.insert(parts, tag[2])
		end
	end
	return table.concat(parts, " ")
end

local function newRow(quest, state, showNames, player)
	local done = state:IsDone(quest.id) and true or false
	local name = quest.name or L["Quest %d"]:format(quest.id)
	return {
		id = quest.id,
		areaID = quest.areaID,
		name = name,
		text = (done or showNames) and name or "???",
		done = done,
		tags = tagString(quest.tags),
		level = quest.level,
		levelText = ns.QuestLevel.Text(quest.level, player),
		forever = quest.forever,
		pre = quest.pre or {},
		children = {},
	}
end

-- Each quest takes its first prerequisite on the same map as its parent, so a chain is a tree.
-- A prerequisite on another map makes the quest the first step of its chain on this map.
local function linkChains(rows)
	local byID = {}
	for _, row in ipairs(rows) do
		byID[row.id] = row
	end
	local roots = {}
	for _, row in ipairs(rows) do
		local parent
		for _, preID in ipairs(row.pre) do
			if byID[preID] and preID ~= row.id then
				parent = byID[preID]
				break
			end
		end
		if parent then
			table.insert(parent.children, row)
		else
			table.insert(roots, row)
		end
	end
	return roots
end

local function collectChain(row, depth, root, out, seen)
	if seen[row] then
		return
	end
	seen[row] = true
	row.depth = depth
	row.groupAreaID = root.areaID
	table.insert(out, row)
	table.sort(row.children, byName)
	for _, child in ipairs(row.children) do
		collectChain(child, depth + 1, root, out, seen)
	end
end

local function chainDone(chain)
	for _, row in ipairs(chain) do
		if not row.done then
			return false
		end
	end
	return true
end

-- Rows come in chain order. Completed chains are first, and each part is sorted by the name of its first step.
function ns.OverviewModel.Quests(index, state, uiMapID, showNames, player)
	local rows = {}
	for _, quest in ipairs(index:QuestsOn(uiMapID)) do
		table.insert(rows, newRow(quest, state, showNames, player))
	end
	local roots = linkChains(rows)
	table.sort(roots, byName)
	local seen, chains = {}, {}
	local function addChain(root)
		local chain = {}
		collectChain(root, 0, root, chain, seen)
		if #chain > 0 then
			table.insert(chains, chain)
		end
	end
	for _, root in ipairs(roots) do
		addChain(root)
	end
	-- Quests in a prerequisite loop have no root, so each one not yet listed starts its own chain.
	table.sort(rows, byName)
	for _, row in ipairs(rows) do
		addChain(row)
	end
	local doneChains, undoneChains = {}, {}
	for _, chain in ipairs(chains) do
		table.insert(chainDone(chain) and doneChains or undoneChains, chain)
	end
	local out = {}
	for _, list in ipairs({ doneChains, undoneChains }) do
		for _, chain in ipairs(list) do
			for _, row in ipairs(chain) do
				row.pre, row.children = nil, nil
				table.insert(out, row)
			end
		end
	end
	return out
end

function ns.OverviewModel.Message(index)
	index:Build()
	if index.error == "zonedata" then
		return L["QuestieDB zone data not found"]
	elseif index.error == "player" then
		return L["Character data not available"]
	end
end

function ns.OverviewModel.QuestGroups(env, index, state, uiMapID, showNames, player)
	local buckets, order = {}, {}
	for _, row in ipairs(ns.OverviewModel.Quests(index, state, uiMapID, showNames, player)) do
		local title = env.C_Map.GetAreaInfo(row.groupAreaID) or OTHER
		local bucket = buckets[title]
		if not bucket then
			bucket = { title = title, quests = {}, done = 0 }
			buckets[title] = bucket
			table.insert(order, bucket)
		end
		table.insert(bucket.quests, row)
		if row.done then
			bucket.done = bucket.done + 1
		end
	end
	table.sort(order, function(a, b)
		local otherA, otherB = a.title == OTHER, b.title == OTHER
		if otherA ~= otherB then
			return otherB
		end
		return a.title:lower() < b.title:lower()
	end)
	local rows = {}
	for _, bucket in ipairs(order) do
		if #order > 1 then
			table.insert(rows, { kind = "area", title = bucket.title, done = bucket.done, total = #bucket.quests })
		end
		for _, quest in ipairs(bucket.quests) do
			quest.kind = "quest"
			table.insert(rows, quest)
		end
	end
	return rows
end

function ns.OverviewModel.CountText(done, total)
	local text = ("%d/%d"):format(done, total)
	if total > 0 and done == total then
		return GOLD .. text .. "|r"
	elseif done == 0 then
		return GREY .. text .. "|r"
	end
	return text
end

function ns.OverviewModel.MapCountText(map)
	local text = ns.OverviewModel.CountText(map.done, map.total)
	if map.unknown > 0 then
		text = GREY .. L["+%d unknown"]:format(map.unknown) .. "|r  " .. text
	end
	return text
end

function ns.OverviewModel.QuestRowText(row)
	local text = row.done and row.text or (GREY .. row.text .. "|r")
	if row.forever then
		text = FOREVER_ICON .. " " .. text
	end
	if row.levelText and row.levelText ~= "" then
		text = row.levelText .. " " .. text
	end
	if row.pinned then
		text = PIN_ICON .. " " .. text
	end
	return text
end
