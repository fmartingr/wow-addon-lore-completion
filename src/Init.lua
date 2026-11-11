local addonName, ns = ...

ns.CONTRACT = 4
ns.onReady = ns.onReady or {}
ns.Init = {}

function ns.Init.Check(env)
	if not env.LibQuestieDB then
		return false, ns.L["LoreCompletion: QuestieDB not found"]
	end
	local ok, message = env.LibQuestieDB.RequireContract(ns.CONTRACT)
	if not ok then
		return false, "LoreCompletion: " .. tostring(message)
	end
	return true
end

-- Fills only missing keys, so saved user values survive a version update.
function ns.Init.ApplyDefaults(db, defaults)
	for key, value in pairs(defaults) do
		if db[key] == nil then
			if type(value) == "table" then
				db[key] = {}
				ns.Init.ApplyDefaults(db[key], value)
			else
				db[key] = value
			end
		end
	end
	return db
end

function ns.Init.OnLoad(env)
	local ok, message = ns.Init.Check(env)
	if not ok then
		ns.disabled = true
		env.print(message)
		return
	end
	LoreCompletionDB = ns.Init.ApplyDefaults(
		LoreCompletionDB or {},
		{ showTracker = true, hideWhenComplete = false, showNames = false }
	)
	LoreCompletionCharDB =
		ns.Init.ApplyDefaults(LoreCompletionCharDB or {}, { unknownQuests = {}, pinned = {}, completedZones = {} })
	for _, fn in ipairs(ns.onReady) do
		fn(env)
	end
end

function ns.Init.BuildEnv()
	return {
		LibQuestieDB = LibQuestieDB,
		QuestDB = QuestDB,
		NpcDB = NpcDB,
		ObjectDB = ObjectDB,
		C_Map = C_Map,
		C_QuestLog = C_QuestLog,
		UnitFactionGroup = UnitFactionGroup,
		UnitClass = UnitClass,
		UnitRace = UnitRace,
		UnitLevel = UnitLevel,
		UnitQuestTrivialLevelRange = UnitQuestTrivialLevelRange,
		GetQuestGreenRange = GetQuestGreenRange,
		Enum = Enum,
		Memories = Memories,
		print = print,
	}
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, arg1)
	if arg1 ~= addonName then
		return
	end
	self:UnregisterEvent("ADDON_LOADED")
	ns.Init.OnLoad(ns.Init.BuildEnv())
end)
