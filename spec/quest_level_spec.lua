local loader = require("spec.helpers.load")
local newEnv = require("spec.helpers.env")

describe("QuestLevel", function()
	local QL
	before_each(function()
		QL = loader.load({ "src/QuestLevel.lua" }).QuestLevel
	end)
	after_each(loader.reset)

	local player = { level = 20, greenRange = 6 }

	describe("IsForever", function()
		it("marks IDs from 10000 up as Forever", function()
			assert.is_false(QL.IsForever(9999))
			assert.is_true(QL.IsForever(10000))
			assert.is_true(QL.IsForever(94003))
		end)
	end)

	describe("Difficulty", function()
		it("follows the Blizzard thresholds", function()
			assert.equals("impossible", QL.Difficulty(25, player))
			assert.equals("veryDifficult", QL.Difficulty(24, player))
			assert.equals("veryDifficult", QL.Difficulty(23, player))
			assert.equals("difficult", QL.Difficulty(22, player))
			assert.equals("difficult", QL.Difficulty(18, player))
			assert.equals("standard", QL.Difficulty(17, player))
			assert.equals("standard", QL.Difficulty(14, player))
			assert.equals("trivial", QL.Difficulty(13, player))
		end)
	end)

	describe("Text", function()
		it("colors the level by difficulty", function()
			assert.equals("|cffff1919[25]|r", QL.Text(25, player))
			assert.equals("|cff808080[5]|r", QL.Text(5, player))
		end)
		it("is plain without a player", function()
			assert.equals("[12]", QL.Text(12, nil))
		end)
		it("is empty for a scaling or missing level", function()
			assert.equals("", QL.Text(0, player))
			assert.equals("", QL.Text(-1, player))
			assert.equals("", QL.Text(nil, player))
		end)
	end)

	describe("Player", function()
		local function level(n)
			return function()
				return n
			end
		end
		it("prefers UnitQuestTrivialLevelRange", function()
			local env = newEnv(nil, {
				UnitLevel = level(30),
				UnitQuestTrivialLevelRange = level(9),
				GetQuestGreenRange = level(4),
			})
			assert.same({ level = 30, greenRange = 9 }, QL.Player(env))
		end)
		it("falls back to GetQuestGreenRange, then to 8", function()
			assert.same(
				{ level = 30, greenRange = 4 },
				QL.Player(newEnv(nil, { UnitLevel = level(30), GetQuestGreenRange = level(4) }))
			)
			assert.same({ level = 30, greenRange = 8 }, QL.Player(newEnv(nil, { UnitLevel = level(30) })))
		end)
		it("uses the event level over UnitLevel", function()
			assert.equals(31, QL.Player(newEnv(nil, { UnitLevel = level(30) }), 31).level)
		end)
		it("is nil without a level", function()
			assert.is_nil(QL.Player(newEnv(nil)))
			assert.is_nil(QL.Player(newEnv(nil, { UnitLevel = level(0) })))
		end)
	end)
end)
