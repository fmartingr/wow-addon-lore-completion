local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = {
	"src/Init.lua",
	"src/Locale.lua",
	"src/Bits.lua",
	"src/QuestLevel.lua",
	"src/QuestFilter.lua",
	"src/QuestIndex.lua",
	"src/Progress.lua",
	"src/QuestState.lua",
	"src/ZoneMemory.lua",
}

describe("ZoneMemory", function()
	local ns, calls, env, index, state, charDB
	local function setup(overrides)
		ns = loader.load(PATHS, overrides)
		calls = {}
		local lib = fake({
			[1] = { name = "A", zoneOrSort = 1 },
			[2] = { name = "B", zoneOrSort = 1 },
		}, { areaToMap = { [1] = 10 } })
		env = newEnv(lib, {
			Memories = {
				RecordEvent = function(...)
					table.insert(calls, { ... })
					return true
				end,
			},
		})
		env.C_Map.GetMapInfo = function()
			return { name = "Elwynn" }
		end
		index = ns.QuestIndex.New(env)
		charDB = { unknownQuests = {}, completedZones = {} }
		state = ns.QuestState.New(env, charDB)
	end
	before_each(setup)
	after_each(loader.reset)

	local function turnIn(id)
		state:OnTurnedIn(id)
		ns.ZoneMemory.OnTurnedIn(env, index, state, charDB, id)
	end

	it("records nothing while quests remain", function()
		turnIn(1)
		assert.equals(0, #calls)
	end)

	it("records once when the last quest is done", function()
		turnIn(1)
		turnIn(2)
		turnIn(2)
		assert.equals(1, #calls)
		assert.same({ "LoreCompletion", "Zone complete: Elwynn", "All 2 quests done" }, calls[1])
		assert.is_true(charDB.completedZones[10])
	end)

	it("writes the note in the game language", function()
		setup({
			GetLocale = function()
				return "esES"
			end,
		})
		turnIn(1)
		turnIn(2)
		assert.same({ "LoreCompletion", "Zona completada: Elwynn", "Las 2 misiones completadas" }, calls[1])
	end)

	it("does nothing without Memories", function()
		env.Memories = nil
		turnIn(1)
		turnIn(2)
		assert.is_nil(charDB.completedZones[10])
	end)

	it("retries after a refused call", function()
		env.Memories.RecordEvent = function()
			return false, "not ready"
		end
		turnIn(1)
		turnIn(2)
		assert.is_nil(charDB.completedZones[10])
	end)
end)
