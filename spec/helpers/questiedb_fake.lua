-- Fake LibQuestieDB with the documented nil semantics (docs/api.md).
local NUMERIC = {
	requiredRaces = true,
	requiredClasses = true,
	zoneOrSort = true,
	questFlags = true,
	specialFlags = true,
	questLevel = true,
	requiredLevel = true,
}

local function serialize(map)
	local parts = {}
	for area, uiMap in pairs(map) do
		table.insert(parts, ("[%d]=%d"):format(area, uiMap))
	end
	return "return {" .. table.concat(parts, ",") .. "}"
end

-- quests: { [id] = { name=, zoneOrSort=, ... } }
-- opts: npcs and objects ({ [id] = { name=, spawns= } }), contractOk (false fails the check), areaToMap ({ [areaID] = uiMapID }), zoneData (raw string override)
return function(quests, opts)
	opts = opts or {}
	local ids = {}
	for id in pairs(quests) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local fake = { calls = { GetAllIds = 0, GetAll = 0 } }
	local Quest = {}
	function Quest.GetAllIds()
		fake.calls.GetAllIds = fake.calls.GetAllIds + 1
		return ids
	end
	function Quest.Exists(id)
		return quests[id] ~= nil
	end
	function Quest.GetAll(id, keys)
		fake.calls.GetAll = fake.calls.GetAll + 1
		local row = quests[id]
		if not row then
			return nil
		end
		local out = { n = #keys }
		for i, key in ipairs(keys) do
			local value = row[key]
			if value == nil and NUMERIC[key] then
				value = 0
			end
			out[i] = value
		end
		return out
	end
	fake.Quest = Quest
	local function entity(rows)
		return {
			GetAll = function(id, keys)
				local row = rows[id]
				if not row then
					return nil
				end
				local out = { n = #keys }
				for i, key in ipairs(keys) do
					out[i] = row[key]
				end
				return out
			end,
		}
	end
	fake.Npc = entity(opts.npcs or {})
	fake.Object = entity(opts.objects or {})
	fake.Enum = {
		raceMaskById = {
			[1] = 1,
			[2] = 2,
			[3] = 4,
			[4] = 8,
			[5] = 16,
			[6] = 32,
			[7] = 64,
			[8] = 128,
			[10] = 512,
			[11] = 1024,
			[22] = 2 ^ 21,
			[25] = 2 ^ 32,
			[26] = 2 ^ 33,
		},
		factionRaceMasks = { Alliance = 1 + 4 + 8 + 64 + 1024 + 2 ^ 32, Horde = 2 + 16 + 32 + 128 + 512 + 2 ^ 33 },
		classKeys = {
			WARRIOR = 1,
			PALADIN = 2,
			HUNTER = 4,
			ROGUE = 8,
			PRIEST = 16,
			DEATH_KNIGHT = 32,
			SHAMAN = 64,
			MAGE = 128,
			WARLOCK = 256,
			MONK = 512,
			DRUID = 1024,
			ALL_CLASSES = 1503,
		},
	}
	local zoneData = opts.zoneData or serialize(opts.areaToMap or {})
	fake.Support = {
		Get = function()
			return { private = { areaIdToUiMapId = zoneData } }
		end,
	}
	function fake.RequireContract()
		if opts.contractOk == false then
			return false, "contract mismatch"
		end
		return true
	end
	return fake
end
