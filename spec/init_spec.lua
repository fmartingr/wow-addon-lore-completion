local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")

describe("Init", function()
	local ns, ctx
	before_each(function()
		ns, ctx = loader.load({ "src/Init.lua", "src/Locale.lua" })
	end)
	after_each(loader.reset)

	local function env(lib)
		return { LibQuestieDB = lib, print = _G.print }
	end

	it("Check passes with a valid fake", function()
		assert.is_true((ns.Init.Check(env(fake({})))))
	end)

	it("Check fails with the reason when the contract fails", function()
		local ok, message = ns.Init.Check(env(fake({}, { contractOk = false })))
		assert.is_false(ok)
		assert.is_truthy(message:find("contract mismatch", 1, true))
	end)

	it("Check fails when LibQuestieDB is nil", function()
		local ok, message = ns.Init.Check(env(nil))
		assert.is_false(ok)
		assert.equals("LoreCompletion: QuestieDB not found", message)
	end)

	it("OnLoad on failure prints once, disables and skips onReady", function()
		local called = false
		table.insert(ns.onReady, function()
			called = true
		end)
		ns.Init.OnLoad(env(fake({}, { contractOk = false })))
		assert.equals(1, #ctx.printed)
		assert.is_true(ns.disabled)
		assert.is_false(called)
		assert.is_nil(loader.G.LoreCompletionDB)
	end)

	it("OnLoad on success fills defaults and keeps existing values", function()
		loader.G.LoreCompletionDB = { showNames = true }
		local called = false
		table.insert(ns.onReady, function()
			called = true
		end)
		ns.Init.OnLoad(env(fake({})))
		local db = loader.G.LoreCompletionDB
		assert.is_true(db.showNames)
		assert.is_true(db.showTracker)
		assert.is_false(db.hideWhenComplete)
		assert.same({}, loader.G.LoreCompletionCharDB.unknownQuests)
		assert.is_true(called)
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
	end)

	it("ADDON_LOADED for another addon does nothing", function()
		local frame = ctx.frames[1]
		assert.is_true(frame.events.ADDON_LOADED)
		frame:Fire("ADDON_LOADED", "OtherAddon")
		assert.is_true(frame.events.ADDON_LOADED)
		assert.is_nil(ns.disabled)
	end)

	it("ADDON_LOADED for this addon runs OnLoad and unregisters", function()
		local frame = ctx.frames[1]
		frame:Fire("ADDON_LOADED", "LoreCompletion")
		assert.is_nil(frame.events.ADDON_LOADED)
		assert.is_true(ns.disabled)
		assert.equals(1, #ctx.printed)
	end)
end)
