-- Pure-module env for tests: Alliance Human Warrior unless overridden.
return function(lib, overrides)
	local env = {
		LibQuestieDB = lib,
		QuestDB = lib and lib.Quest,
		UnitFactionGroup = function()
			return "Alliance", "Alliance"
		end,
		UnitClass = function()
			return "Warrior", "WARRIOR", 1
		end,
		UnitRace = function()
			return "Human", "Human", 1
		end,
		C_Map = {
			GetBestMapForUnit = function()
				return nil
			end,
			GetMapInfo = function()
				return nil
			end,
			GetAreaInfo = function()
				return nil
			end,
		},
		C_QuestLog = {
			IsQuestFlaggedCompleted = function()
				return false
			end,
		},
		print = function() end,
	}
	for key, value in pairs(overrides or {}) do
		env[key] = value
	end
	return env
end
