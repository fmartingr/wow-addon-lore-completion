local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local blizzard = require("spec.helpers.blizzard_stubs")
local tocPaths = require("spec.helpers.toc")

describe("TrackerModule", function()
	local ns, ctx, rec, flagged
	local function boot(configure)
		local globals
		globals, rec = blizzard()
		flagged = {}
		local lib = fake({
			[1] = { name = "A", zoneOrSort = 1 },
			[2] = { name = "B", zoneOrSort = 1 },
		}, { areaToMap = { [1] = 10 } })
		globals.LibQuestieDB, globals.QuestDB = lib, lib.Quest
		globals.C_Map = {
			GetBestMapForUnit = function()
				return 10
			end,
			GetMapInfo = function()
				return { name = "Durotar", mapType = 3, parentMapID = 0 }
			end,
			GetAreaInfo = function() end,
		}
		globals.C_QuestLog = {
			IsQuestFlaggedCompleted = function(id)
				return flagged[id] == true
			end,
		}
		if configure then
			configure(globals, rec)
		end
		ns, ctx = loader.load(tocPaths(), globals)
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		ctx.frames[1]:Fire("ADDON_LOADED", "LoreCompletion")
	end
	after_each(function()
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		loader.G.SLASH_LORECOMPLETION1 = nil
		loader.reset()
	end)

	local function newBlock()
		local bar = { calls = {}, Bar = { colors = {} } }
		function bar:SetPercent(p)
			self.percent = p
		end
		function bar.Bar.GetStatusBarColor()
			return 0.1, 0.2, 0.3
		end
		function bar.Bar:SetStatusBarColor(r, g, b)
			table.insert(self.colors, { r, g, b })
		end
		local block = { bar = bar }
		function block:SetHeader(text)
			self.header = text
		end
		function block:AddObjective(key, text)
			self.objective = { key, text }
		end
		function block:AddProgressBar()
			return self.bar
		end
		return block
	end

	local function layout()
		local block = newBlock()
		local module = {
			GetBlock = function()
				return block
			end,
			LayoutBlock = function(_, b)
				return b
			end,
		}
		return block, ns.TrackerModule.mixin.LayoutContents(module)
	end

	it("sets the module header and uiOrder 0 and attaches to the tracker", function()
		boot()
		local frame = ns.trackerFrame
		assert.equals("Lore", ns.TrackerModule.mixin.headerText)
		assert.equals(0, frame.uiOrder)
		assert.equals(ctx.globals.ObjectiveTrackerFrame, rec.containerCalls[1][2])
		assert.equals(0, #ctx.printed)
	end)

	it("lays out header, objective, bar and percent from the view", function()
		boot()
		flagged[1] = true
		local block, result = layout()
		assert.equals("Durotar", block.header)
		assert.same({ "progress", "1 / 2 quests" }, block.objective)
		assert.equals(50, block.bar.percent)
		assert.equals(block, result)
		assert.equals(10, block.uiMapID)
	end)

	it("uses gold only when complete", function()
		boot()
		flagged[1] = true
		local block = layout()
		assert.same({ { 0.1, 0.2, 0.3 } }, block.bar.Bar.colors)
		flagged[2] = true
		local complete = layout()
		assert.same({ 1, 0.82, 0 }, complete.bar.Bar.colors[1])
	end)

	it("adds no block when the view is nil", function()
		boot()
		loader.G.LoreCompletionDB.showTracker = false
		local block, result = layout()
		assert.is_nil(block.header)
		assert.is_nil(result)
	end)

	it("prints once when SetModuleContainer raises an error", function()
		boot(function(_, r)
			r.managerError = true
		end)
		assert.equals(1, #ctx.printed)
		assert.is_truthy(ctx.printed[1]:find("tracker module not available", 1, true))
	end)

	it("prints once when the container check fails", function()
		boot(function(_, r)
			r.attached = false
		end)
		assert.equals(1, #ctx.printed)
	end)

	it("retries once when the container is not ready at first", function()
		local pending
		boot(function(globals, r)
			r.attached = false
			globals.C_Timer.After = function(_, fn)
				pending = fn
			end
		end)
		assert.equals(0, #ctx.printed)
		rec.attached = true
		pending()
		assert.equals(0, #ctx.printed)
		assert.equals(2, #rec.containerCalls)
	end)

	it("opens the overview on the clicked map", function()
		boot()
		local opened
		ns.Overview.OpenMap = function(id)
			opened = id
		end
		ns.TrackerModule.mixin.OnBlockHeaderClick({}, { uiMapID = 10 })
		assert.equals(10, opened)
	end)

	it("marks the module dirty on zone events and refresh", function()
		boot()
		local dirty = 0
		ns.trackerFrame.MarkDirty = function()
			dirty = dirty + 1
		end
		local eventFrame
		for _, f in ipairs(ctx.frames) do
			if f.events.ZONE_CHANGED then
				eventFrame = f
			end
		end
		for _, event in ipairs({
			"ZONE_CHANGED_NEW_AREA",
			"ZONE_CHANGED",
			"ZONE_CHANGED_INDOORS",
			"PLAYER_ENTERING_WORLD",
		}) do
			assert.is_true(eventFrame.events[event])
			eventFrame:Fire(event)
		end
		assert.equals(4, dirty)
		ns.RunRefresh()
		assert.equals(5, dirty)
	end)

	it("does not register when QuestieDB fails", function()
		boot(function(globals)
			globals.LibQuestieDB.RequireContract = function()
				return false, "nope"
			end
		end)
		assert.is_nil(ns.trackerFrame)
		assert.same({}, rec.containerCalls)
		assert.is_true(ns.disabled)
		assert.equals(1, #ctx.printed)
	end)
end)
