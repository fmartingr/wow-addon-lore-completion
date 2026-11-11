local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local blizzard = require("spec.helpers.blizzard_stubs")
local tocPaths = require("spec.helpers.toc")

describe("integration", function()
	local ns, ctx, flagged
	before_each(function()
		local globals = blizzard()
		flagged = {}
		local lib = fake({
			[1] = { name = "A", zoneOrSort = 1 },
			[2] = { name = "B", zoneOrSort = 1 },
			[3] = { name = "C", zoneOrSort = 1 },
		}, { areaToMap = { [1] = 10 } })
		globals.LibQuestieDB, globals.QuestDB = lib, lib.Quest
		globals.C_Map = {
			GetBestMapForUnit = function()
				return 10
			end,
			GetMapInfo = function()
				return { name = "Durotar", mapType = 3, parentMapID = 0 }
			end,
			GetAreaInfo = function() end,
		}
		globals.C_QuestLog = {
			IsQuestFlaggedCompleted = function(id)
				return flagged[id] == true
			end,
		}
		ns, ctx = loader.load(tocPaths(), globals)
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		ctx.frames[1]:Fire("ADDON_LOADED", "LoreCompletion")
	end)
	after_each(function()
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		loader.G.SLASH_LORECOMPLETION1 = nil
		loader.reset()
	end)

	local function view()
		return ns.TrackerModel.Build(ns.env, ns.index, ns.state, loader.G.LoreCompletionDB)
	end

	local function turnIn(questID)
		for _, f in ipairs(ctx.frames) do
			if f.events.QUEST_TURNED_IN then
				f:Fire("QUEST_TURNED_IN", questID)
				return
			end
		end
	end

	it("moves the tracker from n/m to n+1/m and shows +1 unknown", function()
		flagged[1] = true
		assert.equals("1 / 3 quests", view().text)
		turnIn(2)
		assert.equals("2 / 3 quests", view().text)
		turnIn(77)
		assert.equals("2 / 3 quests", view().text)
		local groups = ns.OverviewModel.Groups(ns.env, ns.index, ns.state)
		local row = groups[1].maps[1]
		assert.equals(10, row.uiMapID)
		assert.equals(1, row.unknown)
		assert.is_truthy(ns.OverviewModel.MapCountText(row):find("+1 unknown", 1, true))
		assert.equals(10, loader.G.LoreCompletionCharDB.unknownQuests[77])
	end)
end)
