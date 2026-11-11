local _, ns = ...

local KEYS = {
	"name",
	"requiredRaces",
	"requiredClasses",
	"zoneOrSort",
	"requiredSkill",
	"questFlags",
	"specialFlags",
	"questLevel",
	"preQuestSingle",
	"preQuestGroup",
	"startedBy",
	"requiredLevel",
}

local Index = {}
Index.__index = Index

ns.QuestIndex = {}

function ns.QuestIndex.New(env)
	return setmetatable({ env = env, built = false, byMap = {}, areaFor = {}, mapOf = {} }, Index)
end

local function loadAreaMap(env)
	local ok, result = pcall(function()
		return loadstring(env.LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId)()
	end)
	if ok and type(result) == "table" then
		return result
	end
end

local function preQuests(row)
	local list = {}
	for _, key in ipairs({ "preQuestSingle", "preQuestGroup" }) do
		local field = row[key]
		if type(field) == "table" then
			for _, id in ipairs(field) do
				list[#list + 1] = id
			end
		end
	end
	return list
end

-- Built once and lazily: about 4,000 quest reads must stay off the login frame.
function Index:Build()
	if self.built then
		return
	end
	self.built = true
	self.error = nil
	local env = self.env
	self.areaToMap = self.areaToMap or loadAreaMap(env)
	local areaToMap = self.areaToMap
	if not areaToMap then
		self.error = "zonedata"
		return
	end
	local player = ns.QuestFilter.Player(env)
	if not player then
		-- A neutral character can pick a faction later, so the next call retries.
		self.built = false
		self.error = "player"
		return
	end
	local allClasses = env.LibQuestieDB.Enum.classKeys.ALL_CLASSES
	for _, id in ipairs(env.QuestDB.GetAllIds()) do
		local v = env.QuestDB.GetAll(id, KEYS)
		if v then
			local row = {
				name = v[1],
				requiredRaces = v[2],
				requiredClasses = v[3],
				zoneOrSort = v[4],
				requiredSkill = v[5],
				questFlags = v[6],
				specialFlags = v[7],
				questLevel = v[8],
				preQuestSingle = v[9],
				preQuestGroup = v[10],
				startedBy = v[11],
				requiredLevel = v[12],
			}
			local eligible, tags = ns.QuestFilter.Evaluate(row, player, allClasses)
			local uiMapID = areaToMap[row.zoneOrSort]
			if eligible and type(uiMapID) == "number" and uiMapID > 0 then
				local list = self.byMap[uiMapID]
				if not list then
					list = {}
					self.byMap[uiMapID] = list
					self.areaFor[uiMapID] = row.zoneOrSort
				end
				self.mapOf[id] = uiMapID
				list[#list + 1] = {
					id = id,
					name = row.name,
					tags = tags,
					areaID = row.zoneOrSort,
					level = row.questLevel,
					forever = ns.QuestLevel.IsForever(id),
					pre = preQuests(row),
					preSingle = row.preQuestSingle,
					preGroup = row.preQuestGroup,
					startedBy = row.startedBy,
					requiredLevel = row.requiredLevel,
				}
			end
		end
	end
end

function Index:QuestsOn(uiMapID)
	self:Build()
	return self.byMap[uiMapID] or {}
end

function Index:MapOf(questID)
	self:Build()
	return self.mapOf[questID]
end

function Index:Maps()
	self:Build()
	local maps = {}
	for uiMapID in pairs(self.byMap) do
		maps[#maps + 1] = uiMapID
	end
	table.sort(maps)
	return maps
end

function Index:AreaFor(uiMapID)
	self:Build()
	return self.areaFor[uiMapID]
end
