local _, ns = ...

ns.Progress = {}

function ns.Progress.For(index, uiMapID, isDone)
	local quests = index:QuestsOn(uiMapID)
	local done = 0
	for _, quest in ipairs(quests) do
		if isDone(quest.id) then
			done = done + 1
		end
	end
	return done, #quests
end
