local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = { "src/Bits.lua", "src/QuestFilter.lua" }

describe("QuestFilter", function()
	local QF, lib, player, ALL
	local function row(overrides)
		local r = { zoneOrSort = 10, requiredRaces = 0, requiredClasses = 0, questFlags = 0, specialFlags = 0 }
		for k, v in pairs(overrides or {}) do
			r[k] = v
		end
		return r
	end
	before_each(function()
		QF = loader.load(PATHS).QuestFilter
		lib = fake({})
		player = QF.Player(newEnv(lib))
		ALL = lib.Enum.classKeys.ALL_CLASSES
	end)
	after_each(loader.reset)

	describe("eligibility", function()
		it("accepts a plain quest", function()
			assert.is_true((QF.Evaluate(row(), player, ALL)))
		end)
		it("rejects zoneOrSort <= 0", function()
			assert.is_false((QF.Evaluate(row({ zoneOrSort = 0 }), player, ALL)))
			assert.is_false((QF.Evaluate(row({ zoneOrSort = -81 }), player, ALL)))
		end)
		it("rejects a nil row (unknown quest)", function()
			assert.is_false((QF.Evaluate(nil, player, ALL)))
		end)
		it("checks the race bit", function()
			assert.is_true((QF.Evaluate(row({ requiredRaces = 1 + 2 }), player, ALL)))
			assert.is_false((QF.Evaluate(row({ requiredRaces = 2 }), player, ALL)))
		end)
		it("checks the class bit", function()
			assert.is_true((QF.Evaluate(row({ requiredClasses = 1 + 2 }), player, ALL)))
			assert.is_false((QF.Evaluate(row({ requiredClasses = 2 }), player, ALL)))
		end)
		it("rejects repeatable quests", function()
			assert.is_false((QF.Evaluate(row({ specialFlags = 1 }), player, ALL)))
			assert.is_false((QF.Evaluate(row({ specialFlags = 3 }), player, ALL)))
			assert.is_true((QF.Evaluate(row({ specialFlags = 2 }), player, ALL)))
		end)
		it("rejects daily, weekly and monthly quests", function()
			assert.is_false((QF.Evaluate(row({ questFlags = 4096 }), player, ALL)))
			assert.is_false((QF.Evaluate(row({ questFlags = 32768 }), player, ALL)))
			assert.is_false((QF.Evaluate(row({ questFlags = 65536 }), player, ALL)))
			assert.is_false((QF.Evaluate(row({ questFlags = 4096 + 8 }), player, ALL)))
			assert.is_true((QF.Evaluate(row({ questFlags = 8 }), player, ALL)))
		end)
		it("handles a Horde Skyborne race bit above 32 bits", function()
			assert.is_false((QF.Evaluate(row({ requiredRaces = 2 ^ 33 }), player, ALL)))
			local horde = QF.Player(newEnv(lib, {
				UnitFactionGroup = function()
					return "Horde"
				end,
				UnitRace = function()
					return "Skyborne", "Skyborne", 26
				end,
			}))
			assert.is_true((QF.Evaluate(row({ requiredRaces = 2 ^ 33 }), horde, ALL)))
		end)
	end)

	describe("tags", function()
		it("tags a class quest", function()
			local _, tags = QF.Evaluate(row({ requiredClasses = 1 }), player, ALL)
			assert.is_true(tags.class)
		end)
		it("does not tag ALL_CLASSES or no class", function()
			assert.is_nil(select(2, QF.Evaluate(row({ requiredClasses = ALL }), player, ALL)).class)
			assert.is_nil(select(2, QF.Evaluate(row(), player, ALL)).class)
		end)
		it("tags a profession quest", function()
			local _, tags = QF.Evaluate(row({ requiredSkill = { 185, 1 } }), player, ALL)
			assert.is_true(tags.profession)
		end)
		it("does not tag nil or zero skill", function()
			assert.is_nil(select(2, QF.Evaluate(row(), player, ALL)).profession)
			assert.is_nil(select(2, QF.Evaluate(row({ requiredSkill = { 0, 0 } }), player, ALL)).profession)
		end)
		it("tags a race quest", function()
			local _, tags = QF.Evaluate(row({ requiredRaces = 1 }), player, ALL)
			assert.is_true(tags.race)
		end)
		it("does not tag a quest for the whole faction", function()
			local mask = lib.Enum.factionRaceMasks.Alliance
			local eligible, tags = QF.Evaluate(row({ requiredRaces = mask }), player, ALL)
			assert.is_true(eligible)
			assert.is_nil(tags.race)
		end)
		it("tags a quest for a subset of the faction mask that includes a foreign bit", function()
			local _, tags = QF.Evaluate(row({ requiredRaces = 1 + 4 }), player, ALL)
			assert.is_true(tags.race)
		end)
	end)

	describe("Player", function()
		it("maps DEATHKNIGHT to DEATH_KNIGHT", function()
			local p = QF.Player(newEnv(lib, {
				UnitClass = function()
					return "Death Knight", "DEATHKNIGHT", 6
				end,
			}))
			assert.equals(32, p.classMask)
		end)
		it("returns nil for a Neutral faction", function()
			local p = QF.Player(newEnv(lib, {
				UnitFactionGroup = function()
					return "Neutral", "Neutral"
				end,
			}))
			assert.is_nil(p)
		end)
		it("returns nil for an unknown race ID", function()
			local p = QF.Player(newEnv(lib, {
				UnitRace = function()
					return "X", "X", 999
				end,
			}))
			assert.is_nil(p)
		end)
	end)
end)
