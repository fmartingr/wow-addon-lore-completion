local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = {
	"src/Locale.lua",
	"src/Bits.lua",
	"src/QuestLevel.lua",
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

		it("adds a colored level and the Forever flag", function()
			local _, index, state = setup({
				[1] = { name = "a", zoneOrSort = 1, questLevel = 30 },
				[12000] = { name = "b", zoneOrSort = 1, questLevel = 10 },
			}, { [1] = 10 })
			local rows = ns.OverviewModel.Quests(index, state, 10, true, { level = 10, greenRange = 5 })
			assert.equals("|cffff1919[30]|r", rows[1].levelText)
			assert.is_false(rows[1].forever)
			assert.equals("|cffffff00[10]|r", rows[2].levelText)
			assert.is_true(rows[2].forever)
		end)

		it("builds the tag string in a fixed order", function()
			local _, index, state = quests()
			local rows = ns.OverviewModel.Quests(index, state, 10, true)
			assert.equals("[Class]", rows[1].tags)
			assert.equals("[Profession] [Race]", rows[2].tags)
			assert.equals("", rows[4].tags)
		end)
	end)

	describe("chains", function()
		local function chainIDs(rows)
			local out = {}
			for _, r in ipairs(rows) do
				table.insert(out, r.id .. ":" .. r.depth)
			end
			return out
		end

		it("lists chain steps after their prerequisite, with depth", function()
			local _, index, state = setup({
				[1] = { name = "Crown", zoneOrSort = 1 },
				[2] = { name = "Crown", zoneOrSort = 1, preQuestSingle = { 1 } },
				[3] = { name = "Crown", zoneOrSort = 1, preQuestSingle = { 2 } },
				[4] = { name = "Apple", zoneOrSort = 1 },
				[5] = { name = "Branch", zoneOrSort = 1, preQuestGroup = { 1 } },
			}, { [1] = 10 })
			local rows = ns.OverviewModel.Quests(index, state, 10, true)
			assert.same({ "4:0", "1:0", "5:1", "2:1", "3:2" }, chainIDs(rows))
		end)

		it("starts a chain at a quest whose prerequisite is on another map", function()
			local _, index, state = setup({
				[1] = { name = "A", zoneOrSort = 2 },
				[2] = { name = "B", zoneOrSort = 1, preQuestSingle = { 1, 99 } },
			}, { [1] = 10, [2] = 20 })
			assert.same({ "2:0" }, chainIDs(ns.OverviewModel.Quests(index, state, 10, true)))
		end)

		it("lists each quest of a prerequisite loop once", function()
			local _, index, state = setup({
				[1] = { name = "A", zoneOrSort = 1, preQuestSingle = { 2 } },
				[2] = { name = "B", zoneOrSort = 1, preQuestSingle = { 1 } },
				[3] = { name = "C", zoneOrSort = 1, preQuestSingle = { 3 } },
			}, { [1] = 10 })
			assert.same({ "3:0", "1:0", "2:1" }, chainIDs(ns.OverviewModel.Quests(index, state, 10, true)))
		end)

		it("puts completed chains first and keeps a partial chain together", function()
			local _, index, state = setup({
				[1] = { name = "A", zoneOrSort = 1 },
				[2] = { name = "A", zoneOrSort = 1, preQuestSingle = { 1 } },
				[3] = { name = "Z", zoneOrSort = 1 },
			}, { [1] = 10 })
			flagged[1], flagged[3] = true, true
			local rows = ns.OverviewModel.Quests(index, state, 10, true)
			assert.same({ "3:0", "1:0", "2:1" }, chainIDs(rows))
			assert.is_nil(rows[1].pre)
			assert.is_nil(rows[1].children)
		end)

		it("groups a chain under the area of its first step", function()
			local env, index, state = setup({
				[1] = { name = "A", zoneOrSort = 900 },
				[2] = { name = "B", zoneOrSort = 901, preQuestSingle = { 1 } },
				[3] = { name = "C", zoneOrSort = 901 },
			}, { [900] = 10, [901] = 10 })
			local rows = ns.OverviewModel.QuestGroups(env, index, state, 10, true)
			local kinds = {}
			for _, r in ipairs(rows) do
				table.insert(kinds, r.kind .. ":" .. (r.title or r.name))
			end
			assert.same({ "area:Area Name", "quest:A", "quest:B", "area:Other", "quest:C" }, kinds)
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

	describe("QuestGroups", function()
		local function areas()
			local env, index, state = setup({
				[1] = { name = "Zeta", zoneOrSort = 900 },
				[2] = { name = "Alpha", zoneOrSort = 900 },
				[3] = { name = "Beta", zoneOrSort = 901 },
			}, { [900] = 10, [901] = 10 })
			return env, index, state
		end

		it("adds no header for a single area", function()
			local env, index, state = setup({ [1] = { name = "a", zoneOrSort = 900 } }, { [900] = 10 })
			local rows = ns.OverviewModel.QuestGroups(env, index, state, 10, true)
			assert.equals(1, #rows)
			assert.equals("quest", rows[1].kind)
		end)

		it("groups quests under an area header and puts unnamed areas last", function()
			local env, index, state = areas()
			flagged[1] = true
			local rows = ns.OverviewModel.QuestGroups(env, index, state, 10, true)
			local kinds = {}
			for _, r in ipairs(rows) do
				table.insert(kinds, r.kind .. ":" .. (r.title or r.name))
			end
			assert.same({ "area:Area Name", "quest:Zeta", "quest:Alpha", "area:Other", "quest:Beta" }, kinds)
			assert.equals(1, rows[1].done)
			assert.equals(2, rows[1].total)
		end)
	end)

	describe("row text", function()
		it("colors the count gold when complete, grey when empty", function()
			assert.equals("|cffffd1002/2|r", ns.OverviewModel.CountText(2, 2))
			assert.equals("|cff9d9d9d0/2|r", ns.OverviewModel.CountText(0, 2))
			assert.equals("1/2", ns.OverviewModel.CountText(1, 2))
		end)
		it("adds the unknown count to the map count", function()
			local text = ns.OverviewModel.MapCountText({ done = 1, total = 2, unknown = 3 })
			assert.is_truthy(text:find("+3 unknown", 1, true))
			assert.is_truthy(text:find("1/2", 1, true))
			assert.equals("1/2", ns.OverviewModel.MapCountText({ done = 1, total = 2, unknown = 0 }))
		end)
		it("puts the level and the Forever icon before the name", function()
			local icon = ns.OverviewModel.FOREVER_ICON
			local row = { text = "Q", done = true, levelText = "[5]", forever = true }
			assert.equals("[5] " .. icon .. " Q", ns.OverviewModel.QuestRowText(row))
			row = { text = "Q", done = false, levelText = "", forever = false }
			assert.equals("|cff9d9d9dQ|r", ns.OverviewModel.QuestRowText(row))
		end)
		it("puts the pin icon first on a pinned quest", function()
			local text = ns.OverviewModel.QuestRowText({ text = "Q", done = true, levelText = "[5]", pinned = true })
			assert.equals(ns.OverviewModel.PIN_ICON .. " [5] Q", text)
		end)
		it("greys undone quest text", function()
			assert.equals("Q", ns.OverviewModel.QuestRowText({ text = "Q", done = true }))
			assert.equals("|cff9d9d9d???|r", ns.OverviewModel.QuestRowText({ text = "???", done = false }))
		end)
	end)
end)
