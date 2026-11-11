local _, ns = ...

ns.ZoneMemory = {}

local SOURCE = "LoreCompletion"

-- Memories is optional. A missing addon or a refused call must not break quest tracking.
function ns.ZoneMemory.OnTurnedIn(env, index, state, charDB, questID)
	local uiMapID = index:MapOf(questID)
	if not uiMapID or charDB.completedZones[uiMapID] then
		return
	end
	local done, total = ns.Progress.For(index, uiMapID, function(id)
		return state:IsDone(id)
	end)
	if total == 0 or done < total then
		return
	end
	local memories = env.Memories
	if not (memories and memories.RecordEvent) then
		return
	end
	local info = env.C_Map.GetMapInfo(uiMapID)
	local name = (info and info.name) or ns.L["Map %d"]:format(uiMapID)
	local ok, recorded = pcall(
		memories.RecordEvent,
		SOURCE,
		ns.L["Zone complete"] .. ": " .. name,
		ns.L["All %d quests done"]:format(total)
	)
	if ok and recorded then
		charDB.completedZones[uiMapID] = true
	end
end
