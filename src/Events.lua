local _, ns = ...

ns.Events = {}

local listeners = {}
local reported = {}
local frame = CreateFrame("Frame")

local function dispatch(_, event, ...)
	for _, fn in ipairs(listeners[event]) do
		local ok, err = pcall(fn, ...)
		if not ok and not reported[event] then
			reported[event] = true
			print(ns.L["LoreCompletion: error in %s handler: %s"]:format(event, tostring(err)))
		end
	end
end

function ns.Events.On(event, fn)
	if not listeners[event] then
		listeners[event] = {}
		frame:RegisterEvent(event)
	end
	table.insert(listeners[event], fn)
end

frame:SetScript("OnEvent", dispatch)

local refreshCallbacks = {}
local refreshFailed = {}

function ns.OnRefresh(fn)
	table.insert(refreshCallbacks, fn)
end

function ns.RunRefresh()
	for i, fn in ipairs(refreshCallbacks) do
		local ok, err = pcall(fn)
		if not ok and not refreshFailed[i] then
			refreshFailed[i] = true
			print(ns.L["LoreCompletion: refresh error: %s"]:format(tostring(err)))
		end
	end
end

table.insert(ns.onReady, function(env)
	ns.env = env
	ns.index = ns.QuestIndex.New(env)
	ns.state = ns.QuestState.New(env, LoreCompletionCharDB)
	ns.givers = ns.GiverModel.New(env, ns.index)
	ns.Events.On("QUEST_TURNED_IN", function(questID)
		ns.state:OnTurnedIn(questID)
		ns.ZoneMemory.OnTurnedIn(env, ns.index, ns.state, LoreCompletionCharDB, questID)
		ns.RunRefresh()
	end)
	ns.Events.On("PLAYER_LEVEL_UP", function(level)
		ns.playerLevel = level
		ns.RunRefresh()
	end)
end)
