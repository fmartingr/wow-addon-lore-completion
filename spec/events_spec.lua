local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = {
	"src/Init.lua",
	"src/Locale.lua",
	"src/Bits.lua",
	"src/QuestLevel.lua",
	"src/QuestFilter.lua",
	"src/QuestIndex.lua",
	"src/Progress.lua",
	"src/QuestState.lua",
	"src/Events.lua",
	"src/ZoneMemory.lua",
	"src/OverviewModel.lua",
	"src/GiverModel.lua",
}

describe("Events", function()
	local ns, ctx, frame
	before_each(function()
		ns, ctx = loader.load(PATHS)
		frame = ctx.frames[2]
	end)
	after_each(loader.reset)

	it("runs listeners in add order", function()
		local order = {}
		ns.Events.On("X", function()
			table.insert(order, 1)
		end)
		ns.Events.On("X", function()
			table.insert(order, 2)
		end)
		frame:Fire("X")
		assert.same({ 1, 2 }, order)
	end)

	it("passes event arguments", function()
		local got
		ns.Events.On("X", function(a, b)
			got = { a, b }
		end)
		frame:Fire("X", 1, 2)
		assert.same({ 1, 2 }, got)
	end)

	it("continues after a listener error and reports once", function()
		local ran = 0
		ns.Events.On("X", function()
			error("boom")
		end)
		ns.Events.On("X", function()
			ran = ran + 1
		end)
		frame:Fire("X")
		frame:Fire("X")
		assert.equals(2, ran)
		assert.equals(1, #ctx.printed)
	end)

	it("registers each event once", function()
		ns.Events.On("X", function() end)
		ns.Events.On("X", function() end)
		local count = 0
		for _, call in ipairs(frame.calls) do
			if call[1] == "RegisterEvent" and call[2] == "X" then
				count = count + 1
			end
		end
		assert.equals(1, count)
	end)

	it("RunRefresh runs callbacks in order and survives errors", function()
		local order = {}
		ns.OnRefresh(function()
			table.insert(order, 1)
			error("boom")
		end)
		ns.OnRefresh(function()
			table.insert(order, 2)
		end)
		ns.RunRefresh()
		ns.RunRefresh()
		assert.same({ 1, 2, 1, 2 }, order)
		assert.equals(1, #ctx.printed)
	end)

	it("QUEST_TURNED_IN updates state and refreshes", function()
		local lib = fake({ [1] = { name = "K", zoneOrSort = 1 } }, { areaToMap = { [1] = 10 } })
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		ns.Init.OnLoad(newEnv(lib, { print = _G.print }))
		local refreshed = 0
		ns.OnRefresh(function()
			refreshed = refreshed + 1
		end)
		frame:Fire("QUEST_TURNED_IN", 1)
		frame:Fire("QUEST_TURNED_IN", 77)
		assert.is_true(ns.state:IsDone(1))
		assert.is_not_nil(loader.G.LoreCompletionCharDB.unknownQuests[77])
		assert.equals(2, refreshed)
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
	end)

	it("PLAYER_LEVEL_UP stores the new level and refreshes", function()
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		ns.Init.OnLoad(newEnv(fake({}), { print = _G.print }))
		local refreshed = 0
		ns.OnRefresh(function()
			refreshed = refreshed + 1
		end)
		frame:Fire("PLAYER_LEVEL_UP", 12)
		assert.equals(12, ns.playerLevel)
		assert.equals(1, refreshed)
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
	end)
end)
