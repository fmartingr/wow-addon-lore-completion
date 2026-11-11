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
	"src/Events.lua",
	"src/ZoneMemory.lua",
	"src/OverviewModel.lua",
	"src/GiverModel.lua",
	"src/OverviewWindow.lua",
}

describe("OverviewWindow", function()
	local ns, ctx, env
	before_each(function()
		ns, ctx = loader.load(PATHS)
		local lib = fake({
			[1] = { name = "A", zoneOrSort = 1, questLevel = 3, startedBy = { { 100 } } },
			[2] = { name = "B", zoneOrSort = 1, preQuestSingle = { 1 } },
		}, { areaToMap = { [1] = 10 }, npcs = { [100] = { name = "N", spawns = { [1] = { { 1, 1 } } } } } })
		env = newEnv(lib, {
			C_Map = {
				GetMapInfo = function()
					return { name = "Durotar", mapType = 3, parentMapID = 0 }
				end,
				GetBestMapForUnit = function()
					return 10
				end,
				GetAreaInfo = function() end,
			},
			UnitLevel = function()
				return 20
			end,
		})
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		ns.Init.OnLoad(env)
	end)
	after_each(function()
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		loader.G.SLASH_LORECOMPLETION1 = nil
		loader.reset()
	end)

	local function overview()
		for _, f in ipairs(ctx.frames) do
			if f.name == "LoreCompletionOverview" then
				return f
			end
		end
	end

	local function boxes()
		local found = {}
		for _, f in ipairs(ctx.frames) do
			if f.template == "WowScrollBoxList" then
				table.insert(found, f)
			end
		end
		return found[1], found[2]
	end

	it("registers /lore and toggles the window", function()
		assert.equals("/lore", loader.G.SLASH_LORECOMPLETION1)
		ctx.globals.SlashCmdList.LORECOMPLETION()
		assert.is_true(overview():IsShown())
		ctx.globals.SlashCmdList.LORECOMPLETION()
		assert.is_false(overview():IsShown())
	end)

	it("adds the frame to UISpecialFrames", function()
		ns.Overview.Toggle()
		assert.same({ "LoreCompletionOverview" }, ctx.globals.UISpecialFrames)
	end)

	it("OpenMap selects the map and fills the quest list", function()
		ns.Overview.OpenMap(10)
		local _, questBox = boxes()
		assert.equals(2, #questBox.data)
		assert.equals("???", questBox.data[1].text)
	end)

	it("colors quest levels by the player level, and by the level-up level", function()
		ns.Overview.OpenMap(10)
		local _, questBox = boxes()
		assert.equals("|cff808080[3]|r", questBox.data[1].levelText)
		ns.playerLevel = 1
		ns.RunRefresh()
		assert.equals("|cffffff00[3]|r", questBox.data[1].levelText)
	end)

	it("indents a chain step under its prerequisite", function()
		ns.Overview.OpenMap(10)
		local _, questBox = boxes()
		assert.equals(0, questBox.data[1].depth)
		assert.equals(1, questBox.data[2].depth)
	end)

	it("a click on a quest pins its giver, and a second click removes the pin", function()
		ns.Overview.OpenMap(10)
		local _, questBox = boxes()
		assert.is_true(questBox.data[1].pinnable)
		assert.is_false(questBox.data[2].pinnable)
		ns.Overview.TogglePin(1)
		assert.is_true(loader.G.LoreCompletionCharDB.pinned[1])
		assert.is_true(questBox.data[1].pinned)
		ns.Overview.TogglePin(1)
		assert.is_nil(loader.G.LoreCompletionCharDB.pinned[1])
		assert.is_false(questBox.data[1].pinned)
	end)

	it("OpenMap for a map not in the index opens with no selection", function()
		ns.Overview.OpenMap(999)
		local _, questBox = boxes()
		assert.is_true(overview():IsShown())
		assert.same({}, questBox.data)
	end)

	it("lists group and map rows", function()
		ns.Overview.Toggle()
		local mapBox = boxes()
		assert.equals("group", mapBox.data[1].kind)
		assert.equals("map", mapBox.data[2].kind)
		assert.equals(10, mapBox.data[2].map.uiMapID)
	end)

	it("Show names writes the saved variable and rebuilds rows", function()
		ns.Overview.OpenMap(10)
		local _, questBox = boxes()
		local check
		for _, f in ipairs(ctx.frames) do
			if f.template == "UICheckButtonTemplate" then
				check = f
			end
		end
		check.checked = true
		check.scripts.OnClick(check)
		assert.is_true(loader.G.LoreCompletionDB.showNames)
		assert.equals("A", questBox.data[1].text)
	end)

	it("shows the message instead of the map list on a data error", function()
		ns.index = ns.QuestIndex.New(newEnv(fake({}, { zoneData = "return {{{" })))
		ns.Overview.Toggle()
		local mapBox = boxes()
		assert.is_false(mapBox:IsShown())
	end)

	it("refresh rebuilds only while shown", function()
		ns.Overview.OpenMap(10)
		local mapBox = boxes()
		local before = #mapBox.calls
		ns.RunRefresh()
		assert.is_true(#mapBox.calls > before)
		overview():Hide()
		before = #mapBox.calls
		ns.RunRefresh()
		assert.equals(before, #mapBox.calls)
	end)
end)
