local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local newEnv = require("spec.helpers.env")

local PATHS = {
	"src/Init.lua",
	"src/Bits.lua",
	"src/QuestFilter.lua",
	"src/QuestIndex.lua",
	"src/Progress.lua",
	"src/QuestState.lua",
	"src/Events.lua",
	"src/OverviewModel.lua",
	"src/OverviewWindow.lua",
}

describe("OverviewWindow", function()
	local ns, ctx, env
	before_each(function()
		ns, ctx = loader.load(PATHS)
		local lib = fake({
			[1] = { name = "A", zoneOrSort = 1 },
			[2] = { name = "B", zoneOrSort = 1 },
		}, { areaToMap = { [1] = 10 } })
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
