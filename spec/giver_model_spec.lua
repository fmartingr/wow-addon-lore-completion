local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = {
	"src/Locale.lua",
	"src/Bits.lua",
	"src/QuestLevel.lua",
	"src/QuestFilter.lua",
	"src/QuestIndex.lua",
	"src/QuestState.lua",
	"src/OverviewModel.lua",
	"src/GiverModel.lua",
}

describe("GiverModel", function()
	local ns, flagged
	before_each(function()
		ns = loader.load(PATHS)
		flagged = {}
	end)
	after_each(loader.reset)

	local player = { level = 10, greenRange = 5 }
	local all = { [1] = true, [2] = true, [3] = true }

	local function setup(quests, npcs, objects, areaToMap)
		local lib = fake(quests, { areaToMap = areaToMap or { [1] = 10, [2] = 20 }, npcs = npcs, objects = objects })
		local env = newEnv(lib, {
			C_QuestLog = {
				IsQuestFlaggedCompleted = function(id)
					return flagged[id] == true
				end,
			},
		})
		local index = ns.QuestIndex.New(env)
		local state = ns.QuestState.New(env, { unknownQuests = {} })
		return ns.GiverModel.New(env, index), state
	end

	local function pinIDs(pins)
		local out = {}
		for _, pin in ipairs(pins) do
			table.insert(out, pin.title .. "@" .. pin.x .. "," .. pin.y .. "#" .. #pin.lines)
		end
		return out
	end

	it("places a pin at each spawn of an NPC giver on its map", function()
		local givers, state = setup({
			[1] = { name = "Q1", zoneOrSort = 1, questLevel = 10, startedBy = { { 100 } } },
			[2] = { name = "Q2", zoneOrSort = 1, questLevel = 8, startedBy = { { 100 } } },
		}, { [100] = { name = "Tenaron", spawns = { [1] = { { 50, 40 }, { 10, 20 } }, [2] = { { 5, 5 } } } } })
		local pins = ns.GiverModel.Pins(givers, state, 10, player, true, all)
		assert.same({ "Tenaron@0.1,0.2#2", "Tenaron@0.5,0.4#2" }, pinIDs(pins))
		assert.equals("|cffffff00[8]|r Q2", pins[1].lines[1])
		assert.equals(1, #ns.GiverModel.Pins(givers, state, 20, player, true, all))
		local everywhere = ns.GiverModel.Pins(givers, state, nil, player, true, all)
		assert.equals(3, #everywhere)
		assert.same({ 10, 10, 20 }, { everywhere[1].uiMapID, everywhere[2].uiMapID, everywhere[3].uiMapID })
	end)

	it("places object givers and skips item starts, instance spawns and unknown givers", function()
		local givers, state = setup({
			[1] = { name = "Q1", zoneOrSort = 1, startedBy = { nil, { 300 }, { 400 } } },
			[2] = { name = "Q2", zoneOrSort = 1, startedBy = { { 999 } } },
			[3] = { name = "Q3", zoneOrSort = 1, startedBy = { { 101 } } },
		}, { [101] = { name = "Inside", spawns = { [1] = { { -1, -1 } } } } }, {
			[300] = { name = "Wanted Poster", spawns = { [1] = { { 30, 30 } } } },
		})
		assert.same({ "Wanted Poster@0.3,0.3#1" }, pinIDs(ns.GiverModel.Pins(givers, state, 10, player, true, all)))
	end)

	it("hides names unless showNames is true", function()
		local givers, state = setup({
			[1] = { name = "Q1", zoneOrSort = 1, startedBy = { { 100 } } },
		}, { [100] = { name = "N", spawns = { [1] = { { 1, 1 } } } } })
		assert.equals("???", ns.GiverModel.Pins(givers, state, 10, nil, false, all)[1].lines[1])
	end)

	it("limits the spawns of one giver on one map", function()
		local points = {}
		for i = 1, 15 do
			table.insert(points, { i, i })
		end
		local givers, state = setup({
			[1] = { name = "Q1", zoneOrSort = 1, startedBy = { { 100 } } },
		}, { [100] = { name = "N", spawns = { [1] = points } } })
		local pins = ns.GiverModel.Pins(givers, state, 10, player, true, all)
		assert.equals(ns.GiverModel.MAX_SPAWNS_PER_MAP, #pins)
	end)

	it("shows only pinned quests that are not done", function()
		local givers, state = setup({
			[1] = { name = "A", zoneOrSort = 1, startedBy = { { 100 } } },
			[2] = { name = "B", zoneOrSort = 1, startedBy = { { 100 } } },
			[3] = { name = "C", zoneOrSort = 1, startedBy = { { 101 } } },
		}, {
			[100] = { name = "N", spawns = { [1] = { { 1, 1 } } } },
			[101] = { name = "M", spawns = { [1] = { { 2, 2 } } } },
		})
		local pinned = { [1] = true, [2] = true }
		assert.same({ "N@0.01,0.01#2" }, pinIDs(ns.GiverModel.Pins(givers, state, 10, player, true, pinned)))
		flagged[1] = true
		assert.same({ "N@0.01,0.01#1" }, pinIDs(ns.GiverModel.Pins(givers, state, 10, player, true, pinned)))
		assert.same({}, ns.GiverModel.Pins(givers, state, 10, player, true, {}))
	end)

	it("knows when a quest can take the player now", function()
		local A = ns.GiverModel.Available
		local _, state = setup({})
		flagged[1] = true
		assert.is_false(A({ id = 1 }, state, player))
		assert.is_false(A({ id = 2, requiredLevel = 11 }, state, player))
		assert.is_true(A({ id = 2, requiredLevel = 11 }, state, nil))
		assert.is_false(A({ id = 2, preSingle = { 50, 51 } }, state, player))
		assert.is_true(A({ id = 2, preSingle = { 50, 1 } }, state, player))
		assert.is_false(A({ id = 2, preGroup = { 1, 52 } }, state, player))
		flagged[52] = true
		assert.is_true(A({ id = 2, preGroup = { 1, 52 } }, state, player))
	end)

	it("dims a pin when no quest is available and above the trivial level", function()
		local givers, state = setup({
			[1] = { name = "Low", zoneOrSort = 1, questLevel = 2, startedBy = { { 100, 101, 102 } } },
			[2] = { name = "Ok", zoneOrSort = 1, questLevel = 9, startedBy = { { 101 } } },
			[3] = { name = "Locked", zoneOrSort = 1, questLevel = 9, preQuestSingle = { 50 }, startedBy = { { 102 } } },
		}, {
			[100] = { name = "A", spawns = { [1] = { { 1, 1 } } } },
			[101] = { name = "B", spawns = { [1] = { { 2, 2 } } } },
			[102] = { name = "C", spawns = { [1] = { { 3, 3 } } } },
		})
		local pins = ns.GiverModel.Pins(givers, state, 10, player, true, all)
		assert.is_true(pins[1].dim)
		assert.is_false(pins[2].dim)
		assert.is_true(pins[3].dim)
		assert.is_false(ns.GiverModel.Pins(givers, state, 10, nil, true, all)[1].dim)
	end)

	it("marks window rows that can take a pin", function()
		local givers = setup({
			[1] = { name = "A", zoneOrSort = 1, startedBy = { { 100 } } },
			[2] = { name = "B", zoneOrSort = 1, startedBy = { nil, nil, { 400 } } },
		}, { [100] = { name = "N", spawns = { [1] = { { 1, 1 } } } } })
		local rows = ns.GiverModel.Annotate(givers, {
			{ kind = "area" },
			{ kind = "quest", id = 1, done = false },
			{ kind = "quest", id = 2, done = false },
			{ kind = "quest", id = 1, done = true },
		}, { [1] = true })
		assert.is_nil(rows[1].pinnable)
		assert.is_true(rows[2].pinnable)
		assert.is_true(rows[2].pinned)
		assert.is_false(rows[3].pinnable)
		assert.is_false(rows[4].pinnable)
		assert.is_false(rows[4].pinned)
	end)

	it("builds once and has no pins while the index has an error", function()
		local lib = fake({}, { zoneData = "return {{{" })
		local env = newEnv(lib)
		local givers = ns.GiverModel.New(env, ns.QuestIndex.New(env))
		assert.same({}, ns.GiverModel.Pins(givers, nil, 10, player, true, all))
		assert.is_false(givers.built)
	end)
end)
