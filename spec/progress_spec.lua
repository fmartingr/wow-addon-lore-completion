local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

describe("Progress", function()
	local ns, index
	before_each(function()
		ns = loader.load({
			"src/Bits.lua",
			"src/QuestLevel.lua",
			"src/QuestFilter.lua",
			"src/QuestIndex.lua",
			"src/Progress.lua",
		})
		local lib = fake({
			[1] = { name = "A", zoneOrSort = 1 },
			[2] = { name = "B", zoneOrSort = 1 },
			[3] = { name = "C", zoneOrSort = 1 },
		}, { areaToMap = { [1] = 10 } })
		index = ns.QuestIndex.New(newEnv(lib))
	end)
	after_each(loader.reset)

	it("returns 0/0 for an unknown map", function()
		local done, total = ns.Progress.For(index, 99, function()
			return true
		end)
		assert.equals(0, done)
		assert.equals(0, total)
	end)

	it("counts done quests", function()
		local done, total = ns.Progress.For(index, 10, function(id)
			return id ~= 2
		end)
		assert.equals(2, done)
		assert.equals(3, total)
	end)
end)
