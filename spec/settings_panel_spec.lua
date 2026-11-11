local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local blizzard = require("spec.helpers.blizzard_stubs")
local tocPaths = require("spec.helpers.toc")

describe("SettingsPanel", function()
	local ns, ctx, rec
	before_each(function()
		local globals
		globals, rec = blizzard()
		local lib = fake({})
		globals.LibQuestieDB, globals.QuestDB = lib, lib.Quest
		ns, ctx = loader.load(tocPaths(), globals)
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		ctx.frames[1]:Fire("ADDON_LOADED", "LoreCompletion")
	end)
	after_each(function()
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		loader.G.SLASH_LORECOMPLETION1 = nil
		loader.reset()
	end)

	it("registers the category with two settings", function()
		assert.equals("LoreCompletion", rec.categories[1].name)
		assert.equals(rec.categories[1], rec.registered)
		assert.equals(2, #rec.settings)
		assert.equals(2, #rec.checkboxes)
	end)

	it("uses the right keys, labels, defaults and table", function()
		local show, hide = rec.settings[1], rec.settings[2]
		assert.equals("showTracker", show.key)
		assert.equals("Show tracker module", show.name)
		assert.is_true(show.default)
		assert.equals("hideWhenComplete", hide.key)
		assert.equals("Hide when complete", hide.name)
		assert.is_false(hide.default)
		assert.equals("boolean", show.varType)
		assert.equals(loader.G.LoreCompletionDB, show.tbl)
		assert.same({}, loader.G.LoreCompletionCharDB.pinned)
	end)

	it("runs a refresh when a value changes", function()
		local refreshed = 0
		ns.OnRefresh(function()
			refreshed = refreshed + 1
		end)
		rec.settings[1].callback(rec.settings[1], false)
		assert.equals(1, refreshed)
	end)
end)
