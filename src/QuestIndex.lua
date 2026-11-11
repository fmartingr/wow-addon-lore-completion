local _, ns = ...

local KEYS = { "name", "requiredRaces", "requiredClasses", "zoneOrSort", "requiredSkill", "questFlags", "specialFlags" }

local Index = {}
Index.__index = Index

ns.QuestIndex = {}

function ns.QuestIndex.New(env)
	return setmetatable({ env = env, built = false, byMap = {}, areaFor = {} }, Index)
end

local function loadAreaMap(env)
	local ok, result = pcall(function()
		return loadstring(env.LibQuestieDB.Support.Get("ZoneDB").private.areaIdToUiMapId)()
	end)
	if ok and type(result) == "table" then
		return result
	end
end

-- Built once and lazily: about 4,000 quest reads must stay off the login frame.
function Index:Build()
	if self.built then
		return
	end
	self.built = true
	local env = self.env
	local areaToMap = loadAreaMap(env)
	if not areaToMap then
		self.error = "zonedata"
		return
	end
	local player = ns.QuestFilter.Player(env)
	if not player then
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
				list[#list + 1] = { id = id, name = row.name, tags = tags, areaID = row.zoneOrSort }
			end
		end
	end
end

function Index:QuestsOn(uiMapID)
	self:Build()
	return self.byMap[uiMapID] or {}
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
