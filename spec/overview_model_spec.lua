local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = {
	"src/Bits.lua",
	"src/QuestFilter.lua",
	"src/QuestIndex.lua",
	"src/Progress.lua",
	"src/QuestState.lua",
	"src/OverviewModel.lua",
}

-- Map tree: 1 Kalimdor (continent) > 10 Durotar (zone); 2 Eastern Kingdoms > 20 Elwynn; 30 dungeon; 40 orphan chain.
local MAPS = {
	[1] = { name = "Kalimdor", mapType = 2, parentMapID = 0 },
	[10] = { name = "Durotar", mapType = 3, parentMapID = 1 },
	[2] = { name = "Eastern Kingdoms", mapType = 2, parentMapID = 0 },
	[20] = { name = "Elwynn Forest", mapType = 3, parentMapID = 2 },
	[21] = { name = "Westfall", mapType = 3, parentMapID = 2 },
	[30] = { name = "Deadmines", mapType = 4, parentMapID = 21 },
	[40] = { name = "Lost", mapType = 3, parentMapID = 41 },
	[41] = { name = "Lost parent", mapType = 3, parentMapID = 0 },
	[50] = { name = "Loop", mapType = 3, parentMapID = 51 },
	[51] = { name = "Loop2", mapType = 3, parentMapID = 50 },
}

describe("OverviewModel", function()
	local ns, flagged
	before_each(function()
		ns = loader.load(PATHS)
		flagged = {}
	end)
	after_each(loader.reset)

	local function setup(quests, areaToMap, maps, mapNow)
		local lib = fake(quests, { areaToMap = areaToMap })
		local env = newEnv(lib, {
			C_Map = {
				GetMapInfo = function(id)
					return (maps or MAPS)[id]
				end,
				GetAreaInfo = function(area)
					return area == 900 and "Area Name" or nil
				end,
				GetBestMapForUnit = function()
					return mapNow
				end,
			},
			C_QuestLog = {
				IsQuestFlaggedCompleted = function(id)
					return flagged[id] == true
				end,
			},
		})
		local charDB = { unknownQuests = {} }
		return env, ns.QuestIndex.New(env), ns.QuestState.New(env, charDB), charDB
	end

	describe("Groups", function()
		it("groups by continent, dungeons and other, sorted", function()
			local env, index, state = setup({
				[1] = { name = "a", zoneOrSort = 1 },
				[2] = { name = "b", zoneOrSort = 2 },
				[3] = { name = "c", zoneOrSort = 3 },
				[4] = { name = "d", zoneOrSort = 4 },
				[5] = { name = "e", zoneOrSort = 5 },
				[6] = { name = "f", zoneOrSort = 6 },
			}, { [1] = 10, [2] = 20, [3] = 30, [4] = 40, [5] = 99, [6] = 50 })
			local groups = ns.OverviewModel.Groups(env, index, state)
			local titles = {}
			for _, g in ipairs(groups) do
				table.insert(titles, g.title)
			end
			assert.same({ "Eastern Kingdoms", "Kalimdor", "Dungeons & Raids", "Other" }, titles)
			assert.equals("Elwynn Forest", groups[1].maps[1].name)
			assert.equals(3, #groups[4].maps)
		end)

		it("sorts maps by name inside a group", function()
			local env, index, state = setup({
				[1] = { name = "a", zoneOrSort = 1 },
				[2] = { name = "b", zoneOrSort = 2 },
			}, { [1] = 21, [2] = 20 })
			local maps = ns.OverviewModel.Groups(env, index, state)[1].maps
			assert.equals("Elwynn Forest", maps[1].name)
			assert.equals("Westfall", maps[2].name)
		end)

		it("falls back to the area name, then to Map <id>", function()
			local env, index, state = setup({
				[1] = { name = "a", zoneOrSort = 900 },
				[2] = { name = "b", zoneOrSort = 901 },
			}, { [900] = 77, [901] = 78 })
			local other = ns.OverviewModel.Groups(env, index, state)[1]
			assert.equals("Other", other.title)
			assert.equals("Area Name", other.maps[1].name)
			assert.equals("Map 78", other.maps[2].name)
		end)

		it("uses info.name for a map in Other with a known name but no continent", function()
			local env, index, state = setup({ [1] = { name = "a", zoneOrSort = 1 } }, { [1] = 40 })
			local other = ns.OverviewModel.Groups(env, index, state)[1]
			assert.equals("Other", other.title)
			assert.equals("Lost", other.maps[1].name)
		end)

		it("computes done, total, complete and unknown", function()
			local env, index, state, charDB = setup({
				[1] = { name = "a", zoneOrSort = 1 },
				[2] = { name = "b", zoneOrSort = 1 },
				[3] = { name = "c", zoneOrSort = 2 },
			}, { [1] = 10, [2] = 20 })
			flagged[1], flagged[2] = true, true
			charDB.unknownQuests[99] = 10
			local groups = ns.OverviewModel.Groups(env, index, state)
			local kalimdor = groups[2].maps[1]
			assert.equals(2, kalimdor.done)
			assert.equals(2, kalimdor.total)
			assert.is_true(kalimdor.complete)
			assert.equals(1, kalimdor.unknown)
			assert.is_false(groups[1].maps[1].complete)
		end)

		it("returns no groups without maps", function()
			local env, index, state = setup({}, {})
			assert.same({}, ns.OverviewModel.Groups(env, index, state))
		end)
	end)

	describe("Quests", function()
		local function quests()
			return setup({
				[1] = { name = "Zeta", zoneOrSort = 1 },
				[2] = { name = "alpha", zoneOrSort = 1, requiredClasses = 1 },
				[3] = { name = "Beta", zoneOrSort = 1, requiredSkill = { 171, 1 }, requiredRaces = 1 },
				[4] = { name = "Gamma", zoneOrSort = 1 },
			}, { [1] = 10 })
		end

		it("lists done first, then undone, each by name", function()
			local _, index, state = quests()
			flagged[1], flagged[4] = true, true
			local rows = ns.OverviewModel.Quests(index, state, 10, true)
			local ids = {}
			for _, r in ipairs(rows) do
				table.insert(ids, r.id)
			end
			assert.same({ 4, 1, 2, 3 }, ids)
		end)

		it("hides undone names but keeps done names and real-name order", function()
			local _, index, state = quests()
			flagged[1] = true
			local rows = ns.OverviewModel.Quests(index, state, 10, false)
			assert.equals("Zeta", rows[1].text)
			assert.equals("???", rows[2].text)
			assert.equals(2, rows[2].id)
			assert.equals(3, rows[3].id)
		end)

		it("shows names when showNames is true", function()
			local _, index, state = quests()
			assert.equals("alpha", ns.OverviewModel.Quests(index, state, 10, true)[1].text)
		end)

		it("builds the tag string in a fixed order", function()
			local _, index, state = quests()
			local rows = ns.OverviewModel.Quests(index, state, 10, true)
			assert.equals("[Class]", rows[1].tags)
			assert.equals("[Profession] [Race]", rows[2].tags)
			assert.equals("", rows[4].tags)
		end)
	end)

	describe("Message", function()
		it("is nil without errors", function()
			local _, index = setup({}, {})
			assert.is_nil(ns.OverviewModel.Message(index))
		end)
		it("reports missing zone data", function()
			local lib = fake({}, { zoneData = "return {{{" })
			local index = ns.QuestIndex.New(newEnv(lib))
			assert.equals("QuestieDB zone data not found", ns.OverviewModel.Message(index))
		end)
		it("reports missing character data", function()
			local lib = fake({}, {})
			local index = ns.QuestIndex.New(newEnv(lib, {
				UnitFactionGroup = function()
					return "Neutral"
				end,
			}))
			assert.equals("Character data not available", ns.OverviewModel.Message(index))
		end)
	end)

	describe("row text", function()
		it("shows gold for complete maps and the unknown count", function()
			local text = ns.OverviewModel.MapRowText({ name = "X", done = 2, total = 2, complete = true, unknown = 3 })
			assert.is_truthy(text:find("|cffffd100X  2/2|r", 1, true))
			assert.is_truthy(text:find("+3 unknown", 1, true))
		end)
		it("shows plain text for an incomplete map without unknowns", function()
			local text = ns.OverviewModel.MapRowText({ name = "X", done = 1, total = 2, complete = false, unknown = 0 })
			assert.equals("X  1/2", text)
		end)
		it("adds tags and a done mark to quest rows", function()
			local done = ns.OverviewModel.QuestRowText({ text = "Q", tags = "[Race]", done = true })
			assert.is_truthy(done:find("ReadyCheck", 1, true))
			assert.is_truthy(done:find("Q  [Race]", 1, true))
			assert.equals("???", ns.OverviewModel.QuestRowText({ text = "???", tags = "", done = false }))
		end)
	end)
end)
