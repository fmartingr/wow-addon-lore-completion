local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

describe("QuestState", function()
	local ns, flagged, mapID, charDB, state
	before_each(function()
		ns = loader.load({ "src/QuestState.lua" })
		flagged, mapID = {}, 5
		charDB = { unknownQuests = {} }
		local lib = fake({ [1] = { name = "Known", zoneOrSort = 1 } })
		state = ns.QuestState.New(
			newEnv(lib, {
				C_QuestLog = {
					IsQuestFlaggedCompleted = function(id)
						return flagged[id] == true
					end,
				},
				C_Map = {
					GetBestMapForUnit = function()
						return mapID
					end,
				},
			}),
			charDB
		)
	end)
	after_each(loader.reset)

	it("IsDone is true from the cache before the flag", function()
		assert.is_false(state:IsDone(1))
		state:OnTurnedIn(1)
		assert.is_true(state:IsDone(1))
	end)

	it("IsDone is true from the flag", function()
		flagged[2] = true
		assert.is_true(state:IsDone(2))
	end)

	it("IsDone is false otherwise", function()
		assert.is_false(state:IsDone(3))
	end)

	it("stores the map for an unknown quest", function()
		state:OnTurnedIn(99)
		assert.equals(5, charDB.unknownQuests[99])
	end)

	it("stores nothing for a known quest", function()
		state:OnTurnedIn(1)
		assert.same({}, charDB.unknownQuests)
	end)

	it("stores 0 when the map is nil", function()
		mapID = nil
		state:OnTurnedIn(99)
		assert.equals(0, charDB.unknownQuests[99])
	end)

	it("keeps one entry when a quest is turned in twice", function()
		state:OnTurnedIn(99)
		state:OnTurnedIn(99)
		assert.equals(1, state:UnknownCount(5))
	end)

	it("counts unknown quests per map", function()
		state:OnTurnedIn(98)
		state:OnTurnedIn(99)
		mapID = 6
		state:OnTurnedIn(97)
		assert.equals(2, state:UnknownCount(5))
		assert.equals(1, state:UnknownCount(6))
		assert.equals(0, state:UnknownCount(7))
	end)
end)
