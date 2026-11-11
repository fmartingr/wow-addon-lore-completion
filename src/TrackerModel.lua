local _, ns = ...

ns.TrackerModel = {}

function ns.TrackerModel.Build(env, index, state, db)
	if not db.showTracker then
		return nil
	end
	local uiMapID = env.C_Map.GetBestMapForUnit("player")
	if not uiMapID then
		return nil
	end
	local done, total = ns.Progress.For(index, uiMapID, function(id)
		return state:IsDone(id)
	end)
	if total == 0 then
		return nil
	end
	local complete = done == total
	if complete and db.hideWhenComplete then
		return nil
	end
	local info = env.C_Map.GetMapInfo(uiMapID)
	return {
		uiMapID = uiMapID,
		title = (info and info.name) or ("Map " .. uiMapID),
		text = complete and "Complete" or ("%d / %d quests"):format(done, total),
		percent = math.floor(done / total * 100),
		complete = complete,
	}
end
