local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = { "src/Bits.lua", "src/QuestLevel.lua", "src/QuestFilter.lua", "src/QuestIndex.lua" }

describe("QuestIndex", function()
	local ns
	before_each(function()
		ns = loader.load(PATHS)
	end)
	after_each(loader.reset)

	local quests = {
		[1] = { name = "A", zoneOrSort = 100 },
		[2] = { name = "B", zoneOrSort = 100, requiredClasses = 1 },
		[3] = { name = "C", zoneOrSort = 200 },
		[4] = { name = "D", zoneOrSort = 201 }, -- second AreaID on map 20
		[5] = { name = "E", zoneOrSort = 100, requiredRaces = 2 }, -- Orc only
		[6] = { name = "F", zoneOrSort = 100, questFlags = 4096 },
		[7] = { name = "G", zoneOrSort = -5 },
		[8] = { name = "H", zoneOrSort = 300 }, -- AreaID not in the map
		[9] = { name = "I", zoneOrSort = 400 }, -- AreaID maps to 0
		[10] = { name = "J", zoneOrSort = 100, requiredSkill = { 171, 1 } },
		[11] = { name = "L", zoneOrSort = 200, preQuestGroup = { 3 } },
		[94003] = { name = "K", zoneOrSort = 200, questLevel = 42, preQuestSingle = { 3 }, preQuestGroup = { 4 } },
	}
	local areaToMap = { [100] = 10, [200] = 20, [201] = 20, [400] = 0 }

	local function build(extra)
		local lib = fake(quests, { areaToMap = areaToMap })
		local index = ns.QuestIndex.New(newEnv(lib, extra))
		return index, lib
	end

	local function ids(list)
		local out = {}
		for _, q in ipairs(list) do
			out[#out + 1] = q.id
		end
		return out
	end

	it("lists eligible quests by map", function()
		local index = build()
		assert.same({ 1, 2, 10 }, ids(index:QuestsOn(10)))
		assert.same({ 3, 4, 11, 94003 }, ids(index:QuestsOn(20)))
	end)

	it("carries name, tags and areaID", function()
		local index = build()
		local q = index:QuestsOn(10)[2]
		assert.equals("B", q.name)
		assert.is_true(q.tags.class)
		assert.equals(100, q.areaID)
	end)

	it("excludes ineligible, zoneless and unmapped quests", function()
		local index = build()
		local all = {}
		for _, map in ipairs(index:Maps()) do
			for _, id in ipairs(ids(index:QuestsOn(map))) do
				all[id] = true
			end
		end
		for _, id in ipairs({ 5, 6, 7, 8, 9 }) do
			assert.is_nil(all[id])
		end
		assert.same({ 10, 20 }, index:Maps())
	end)

	it("carries the quest level and the Forever flag", function()
		local index = build()
		local classic, forever = index:QuestsOn(20)[1], index:QuestsOn(20)[4]
		assert.equals(0, classic.level)
		assert.is_false(classic.forever)
		assert.equals(42, forever.level)
		assert.is_true(forever.forever)
	end)

	it("joins single and group prerequisites", function()
		local index = build()
		assert.same({ 3, 4 }, index:QuestsOn(20)[4].pre)
		assert.same({ 3 }, index:QuestsOn(20)[3].pre)
		assert.same({}, index:QuestsOn(20)[1].pre)
	end)

	it("returns an empty list for an unknown or nil map", function()
		local index = build()
		assert.same({}, index:QuestsOn(999))
		assert.same({}, index:QuestsOn(nil))
	end)

	it("builds once", function()
		local index, lib = build()
		index:Build()
		index:Build()
		index:QuestsOn(10)
		assert.equals(1, lib.calls.GetAllIds)
	end)

	it("reports the first AreaID of a map", function()
		local index = build()
		assert.equals(200, index:AreaFor(20))
	end)

	it("sets error and stays empty for a malformed zone string", function()
		local lib = fake(quests, { zoneData = "return {{{" })
		local index = ns.QuestIndex.New(newEnv(lib))
		assert.same({}, index:QuestsOn(10))
		assert.equals("zonedata", index.error)
		assert.same({}, index:Maps())
	end)

	it("sets error for a non-table zone result", function()
		local lib = fake(quests, { zoneData = "return 5" })
		local index = ns.QuestIndex.New(newEnv(lib))
		index:Build()
		assert.equals("zonedata", index.error)
	end)

	it("sets error when the zone support is missing", function()
		local lib = fake(quests, { areaToMap = areaToMap })
		lib.Support.Get = function()
			return nil
		end
		local index = ns.QuestIndex.New(newEnv(lib))
		index:Build()
		assert.equals("zonedata", index.error)
	end)

	it("retries after a player error", function()
		local faction = "Neutral"
		local index = build({
			UnitFactionGroup = function()
				return faction
			end,
		})
		assert.same({}, index:Maps())
		faction = "Alliance"
		assert.same({ 10, 20 }, index:Maps())
		assert.is_nil(index.error)
	end)

	it("sets error for a neutral player", function()
		local index = build({
			UnitFactionGroup = function()
				return "Neutral"
			end,
		})
		index:Build()
		assert.equals("player", index.error)
		assert.same({}, index:Maps())
	end)
end)
