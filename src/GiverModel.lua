local _, ns = ...

local L = ns.L
local KEYS = { "name", "spawns" }
-- A quest giver that wanders has many spawn points. More pins than this only fill the map.
local MAX_SPAWNS_PER_MAP = 10

local Givers = {}
Givers.__index = Givers

ns.GiverModel = { MAX_SPAWNS_PER_MAP = MAX_SPAWNS_PER_MAP }

function ns.GiverModel.New(env, index)
	return setmetatable({ env = env, index = index, built = false, byMap = {}, byQuest = {} }, Givers)
end

local function read(db, cache, id)
	if cache[id] == nil then
		local v = db and db.GetAll(id, KEYS)
		cache[id] = v and { name = v[1], spawns = v[2] } or false
	end
	return cache[id] or nil
end

function Givers:add(kind, id, entry, quest)
	if type(entry.spawns) ~= "table" then
		return
	end
	local areaToMap = self.index.areaToMap
	for areaID, points in pairs(entry.spawns) do
		local uiMapID = areaToMap[areaID]
		if type(uiMapID) == "number" and uiMapID > 0 and type(points) == "table" then
			local byKey = self.byMap[uiMapID] or {}
			self.byMap[uiMapID] = byKey
			local placed = 0
			for _, point in ipairs(points) do
				local x, y = point[1], point[2]
				-- QuestieDB uses (-1, -1) for a spawn inside an instance.
				if placed < MAX_SPAWNS_PER_MAP and x and y and x >= 0 and y >= 0 then
					placed = placed + 1
					local key = ("%s:%d:%d:%d"):format(kind, id, math.floor(x * 100), math.floor(y * 100))
					local giver = byKey[key]
					if not giver then
						giver = { name = entry.name, uiMapID = uiMapID, x = x / 100, y = y / 100, quests = {} }
						byKey[key] = giver
					end
					table.insert(giver.quests, quest)
					local list = self.byQuest[quest.id] or {}
					self.byQuest[quest.id] = list
					table.insert(list, giver)
				end
			end
		end
	end
end

-- Built once and lazily, after the quest index, so the first world map open pays the cost.
function Givers:Build()
	if self.built then
		return
	end
	self.index:Build()
	if self.index.error then
		return
	end
	self.built = true
	local env, npcs, objects = self.env, {}, {}
	for _, uiMapID in ipairs(self.index:Maps()) do
		for _, quest in ipairs(self.index:QuestsOn(uiMapID)) do
			local startedBy = quest.startedBy
			if type(startedBy) == "table" then
				for _, npcID in ipairs(startedBy[1] or {}) do
					local entry = read(env.NpcDB, npcs, npcID)
					if entry then
						self:add("npc", npcID, entry, quest)
					end
				end
				for _, objectID in ipairs(startedBy[2] or {}) do
					local entry = read(env.ObjectDB, objects, objectID)
					if entry then
						self:add("object", objectID, entry, quest)
					end
				end
			end
		end
	end
end

local function anyDone(ids, state)
	for _, id in ipairs(ids) do
		if state:IsDone(id) then
			return true
		end
	end
	return false
end

local function allDone(ids, state)
	for _, id in ipairs(ids) do
		if not state:IsDone(id) then
			return false
		end
	end
	return true
end

-- QuestieDB semantics: one quest of preQuestSingle is enough, and every quest of preQuestGroup is necessary.
function ns.GiverModel.Available(quest, state, player)
	if state:IsDone(quest.id) then
		return false
	end
	if player and (quest.requiredLevel or 0) > player.level then
		return false
	end
	local single, group = quest.preSingle, quest.preGroup
	if type(single) == "table" and #single > 0 and not anyDone(single, state) then
		return false
	end
	if type(group) == "table" and not allDone(group, state) then
		return false
	end
	return true
end

local function byLevel(a, b)
	if (a.level or 0) ~= (b.level or 0) then
		return (a.level or 0) < (b.level or 0)
	end
	return a.id < b.id
end

function ns.GiverModel.Located(givers, questID)
	givers:Build()
	return givers.byQuest[questID] ~= nil
end

-- Adds the pin fields to the quest rows of the overview window.
function ns.GiverModel.Annotate(givers, rows, pinned)
	for _, row in ipairs(rows) do
		if row.kind == "quest" then
			row.pinnable = not row.done and ns.GiverModel.Located(givers, row.id)
			row.pinned = row.pinnable and pinned[row.id] == true
		end
	end
	return rows
end

-- The givers of the pinned quests, on one map, or on all maps when uiMapID is nil.
local function pinnedGivers(givers, uiMapID, pinned)
	local out, seen = {}, {}
	for questID in pairs(pinned) do
		for _, giver in ipairs(givers.byQuest[questID] or {}) do
			if not seen[giver] and (uiMapID == nil or giver.uiMapID == uiMapID) then
				seen[giver] = true
				table.insert(out, giver)
			end
		end
	end
	return out
end

-- One pin for each spawn point of a giver with at least one pinned quest that is not done.
-- A pin is dim when none of its quests is available and above the trivial level.
function ns.GiverModel.Pins(givers, state, uiMapID, player, showNames, pinned)
	givers:Build()
	local pins = {}
	for _, giver in ipairs(pinnedGivers(givers, uiMapID, pinned)) do
		local quests, dim = {}, true
		for _, quest in ipairs(giver.quests) do
			if pinned[quest.id] and not state:IsDone(quest.id) then
				table.insert(quests, quest)
				local level = quest.level or 0
				local trivial = player and level > 0 and ns.QuestLevel.Difficulty(level, player) == "trivial"
				if ns.GiverModel.Available(quest, state, player) and not trivial then
					dim = false
				end
			end
		end
		if #quests > 0 then
			table.sort(quests, byLevel)
			local lines = {}
			for _, quest in ipairs(quests) do
				local name = showNames and (quest.name or L["Quest %d"]:format(quest.id)) or "???"
				table.insert(
					lines,
					ns.OverviewModel.QuestRowText({
						text = name,
						done = true,
						levelText = ns.QuestLevel.Text(quest.level, player),
						forever = quest.forever,
					})
				)
			end
			table.insert(
				pins,
				{ uiMapID = giver.uiMapID, x = giver.x, y = giver.y, title = giver.name, lines = lines, dim = dim }
			)
		end
	end
	table.sort(pins, function(a, b)
		if a.uiMapID ~= b.uiMapID then
			return a.uiMapID < b.uiMapID
		end
		if a.y ~= b.y then
			return a.y < b.y
		end
		return a.x < b.x
	end)
	return pins
end
