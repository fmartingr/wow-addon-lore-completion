local _, ns = ...

local State = {}
State.__index = State

ns.QuestState = {}

function ns.QuestState.New(env, charDB)
	return setmetatable({ env = env, charDB = charDB, cache = {} }, State)
end

-- The session cache covers the gap where QUEST_TURNED_IN fires before the completed flag is true.
function State:IsDone(id)
	return self.cache[id] or self.env.C_QuestLog.IsQuestFlaggedCompleted(id) or false
end

function State:OnTurnedIn(questID)
	self.cache[questID] = true
	if not self.env.QuestDB.Exists(questID) then
		self.charDB.unknownQuests[questID] = self.env.C_Map.GetBestMapForUnit("player") or 0
	end
end

function State:UnknownCount(uiMapID)
	local count = 0
	for id, mapID in pairs(self.charDB.unknownQuests) do
		-- QuestieDB may learn the quest later. Then it counts in done/total instead.
		if mapID == uiMapID and not self.env.QuestDB.Exists(id) then
			count = count + 1
		end
	end
	return count
end
