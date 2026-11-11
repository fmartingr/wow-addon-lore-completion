local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = {
	"src/Bits.lua",
	"src/QuestFilter.lua",
	"src/QuestIndex.lua",
	"src/Progress.lua",
	"src/QuestState.lua",
	"src/TrackerModel.lua",
}

describe("TrackerModel", function()
	local ns, flagged, mapNow, info
	before_each(function()
		ns = loader.load(PATHS)
		flagged, mapNow, info = {}, 10, { name = "Durotar" }
	end)
	after_each(loader.reset)

	local function setup(count)
		local quests = {}
		for i = 1, count do
			quests[i] = { name = "Q" .. i, zoneOrSort = 1 }
		end
		local env = newEnv(fake(quests, { areaToMap = { [1] = 10 } }), {
			C_Map = {
				GetBestMapForUnit = function()
					return mapNow
				end,
				GetMapInfo = function()
					return info
				end,
			},
			C_QuestLog = {
				IsQuestFlaggedCompleted = function(id)
					return flagged[id] == true
				end,
			},
		})
		return env, ns.QuestIndex.New(env), ns.QuestState.New(env, { unknownQuests = {} })
	end

	local db = function(overrides)
		local out = { showTracker = true, hideWhenComplete = false }
		for k, v in pairs(overrides or {}) do
			out[k] = v
		end
		return out
	end

	it("is nil when showTracker is false", function()
		local env, index, state = setup(2)
		assert.is_nil(ns.TrackerModel.Build(env, index, state, db({ showTracker = false })))
	end)

	it("is nil when the map is nil", function()
		local env, index, state = setup(2)
		mapNow = nil
		assert.is_nil(ns.TrackerModel.Build(env, index, state, db()))
	end)

	it("is nil when total is 0 (not complete)", function()
		local env, index, state = setup(0)
		assert.is_nil(ns.TrackerModel.Build(env, index, state, db()))
	end)

	it("shows text and percent for 34/72", function()
		local env, index, state = setup(72)
		for i = 1, 34 do
			flagged[i] = true
		end
		local view = ns.TrackerModel.Build(env, index, state, db())
		assert.equals("34 / 72 quests", view.text)
		assert.equals(47, view.percent)
		assert.is_false(view.complete)
		assert.equals("Durotar", view.title)
		assert.equals(10, view.uiMapID)
	end)

	it("shows Complete and the flag", function()
		local env, index, state = setup(2)
		flagged[1], flagged[2] = true, true
		local view = ns.TrackerModel.Build(env, index, state, db())
		assert.equals("Complete", view.text)
		assert.is_true(view.complete)
		assert.equals(100, view.percent)
	end)

	it("hides a complete map when hideWhenComplete is on", function()
		local env, index, state = setup(2)
		flagged[1], flagged[2] = true, true
		assert.is_nil(ns.TrackerModel.Build(env, index, state, db({ hideWhenComplete = true })))
	end)

	it("shows an incomplete map when hideWhenComplete is on", function()
		local env, index, state = setup(2)
		flagged[1] = true
		assert.is_not_nil(ns.TrackerModel.Build(env, index, state, db({ hideWhenComplete = true })))
	end)

	it("falls back to Map <id> when GetMapInfo is nil", function()
		local env, index, state = setup(2)
		info = nil
		assert.equals("Map 10", ns.TrackerModel.Build(env, index, state, db()).title)
	end)
end)
