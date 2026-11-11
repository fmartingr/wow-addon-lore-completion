local loader = require("spec.helpers.load")
local fake = require("spec.helpers.questiedb_fake")
local blizzard = require("spec.helpers.blizzard_stubs")
local tocPaths = require("spec.helpers.toc")

describe("GiverPins", function()
	local ns, ctx, map, tooltip, flagged

	local function load(withMap, openMap)
		local globals = blizzard()
		flagged = {}
		local lib = fake({
			[1] = { name = "Q1", zoneOrSort = 1, questLevel = 1, startedBy = { { 100 } } },
			[2] = { name = "Q2", zoneOrSort = 2, startedBy = { { 101 } } },
			[3] = { name = "Q3", zoneOrSort = 3, startedBy = { { 102 } } },
		}, {
			areaToMap = { [1] = 10, [2] = 20, [3] = 30 },
			npcs = {
				[100] = { name = "Giver", spawns = { [1] = { { 50, 25 } } } },
				[101] = { name = "Neighbor", spawns = { [2] = { { 30, 40 } } } },
				[102] = { name = "Far", spawns = { [3] = { { 10, 10 } } } },
			},
		})
		globals.OpenMapAPI = openMap
		globals.LibQuestieDB, globals.QuestDB, globals.NpcDB, globals.ObjectDB = lib, lib.Quest, lib.Npc, lib.Object
		globals.UnitLevel = function()
			return 10
		end
		globals.C_QuestLog = {
			IsQuestFlaggedCompleted = function(id)
				return flagged[id] == true
			end,
		}
		globals.MapCanvasDataProviderMixin = {}
		tooltip = { lines = {} }
		function tooltip.SetOwner() end
		function tooltip.AddLine(_, text)
			table.insert(tooltip.lines, text)
		end
		function tooltip.Show()
			tooltip.shown = true
		end
		function tooltip.Hide()
			tooltip.shown = false
		end
		globals.GameTooltip = tooltip
		map = { shown = true, scale = 2, providers = {} }
		if withMap then
			function map.AddDataProvider(self, provider)
				table.insert(self.providers, provider)
				provider.GetMap = function()
					return self
				end
			end
			function map.IsShown(self)
				return self.shown
			end
			function map.GetMapID()
				return 10
			end
			function map.GetCanvasScale(self)
				return self.scale
			end
			function map.GetCanvas(self)
				if not self.canvas then
					self.canvas = ctx.globals.CreateFrame("Frame")
					self.canvas.GetSize = function()
						return 1000, 800
					end
				end
				return self.canvas
			end
			globals.WorldMapFrame = map
		end
		ns, ctx = loader.load(tocPaths(), globals)
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		ctx.frames[1]:Fire("ADDON_LOADED", "LoreCompletion")
		local pinned = loader.G.LoreCompletionCharDB.pinned
		pinned[1], pinned[2], pinned[3] = true, true, true
	end

	after_each(function()
		loader.G.LoreCompletionDB, loader.G.LoreCompletionCharDB = nil, nil
		loader.G.SLASH_LORECOMPLETION1 = nil
		loader.reset()
	end)

	local function pins()
		local out = {}
		for _, f in ipairs(ctx.frames) do
			if f.data and f.data.title and f.shown then
				table.insert(out, f)
			end
		end
		return out
	end

	local function call(frame, name)
		for i = #frame.calls, 1, -1 do
			if frame.calls[i][1] == name then
				return frame.calls[i]
			end
		end
	end

	it("adds one provider and draws a pin at the spawn, sized for the canvas scale", function()
		load(true)
		assert.equals(1, #map.providers)
		map.providers[1]:RefreshAllData()
		local list = pins()
		assert.equals(1, #list)
		local point = call(list[1], "SetPoint")
		assert.same({ "SetPoint", "CENTER", point[3], "TOPLEFT", 500, -200 }, point)
		assert.same({ "SetSize", 9, 9 }, call(list[1], "SetSize"))
	end)

	it("shows the giver and its quests in the tooltip", function()
		load(true)
		map.providers[1]:RefreshAllData()
		local pin = pins()[1]
		pin.scripts.OnEnter(pin)
		assert.equals("Giver", tooltip.lines[1])
		assert.equals("|cff808080[1]|r ???", tooltip.lines[2])
		pin.scripts.OnLeave(pin)
		assert.is_false(tooltip.shown)
	end)

	it("removes pins when the quest is unpinned, the map is hidden, or the quest is done", function()
		load(true)
		map.providers[1]:RefreshAllData()
		loader.G.LoreCompletionCharDB.pinned[1] = nil
		ns.RunRefresh()
		assert.equals(0, #pins())
		loader.G.LoreCompletionCharDB.pinned[1] = true
		map.shown = false
		ns.RunRefresh()
		assert.equals(0, #pins())
		map.shown = true
		flagged[1] = true
		ns.state.cache = {}
		map.providers[1]:OnMapChanged()
		assert.equals(0, #pins())
	end)

	it("attaches later when the world map loads after the addon", function()
		load(false)
		assert.is_nil(map.AddDataProvider)
		loader.G.WorldMapFrame = map
		function map.AddDataProvider(self, provider)
			table.insert(self.providers, provider)
		end
		for _, f in ipairs(ctx.frames) do
			if f.events.PLAYER_ENTERING_WORLD and f.scripts.OnEvent then
				f:Fire("PLAYER_ENTERING_WORLD")
				f:Fire("PLAYER_ENTERING_WORLD")
			end
		end
		assert.equals(1, #map.providers)
		loader.G.WorldMapFrame = nil
	end)

	it("draws every pinned giver on the OpenMap stitched map, above its art", function()
		local api = { callbacks = {}, stitched = true }
		function api.IsStitched()
			return api.stitched
		end
		function api.WorldFromMap(uiMapID, x, y)
			if uiMapID == 20 then
				return x + 1, y
			elseif uiMapID == 10 then
				return x, y
			end
		end
		function api.MapFromWorld(_, u, v)
			return u, v
		end
		function api.ArtTopLevel()
			return 500
		end
		function api.RegisterCallback(_, event, fn)
			api.callbacks[event] = fn
		end
		load(true, api)
		api.callbacks.OpenMap_StitchedChanged(true)
		local titles = {}
		for _, pin in ipairs(pins()) do
			local point = call(pin, "SetPoint")
			titles[pin.data.title] = { point[5], point[6] }
		end
		assert.same({ Giver = { 500, -200 }, Neighbor = { 1300, -320 } }, titles)
		assert.same({ "SetFrameLevel", 501 }, call(pins()[1].parent, "SetFrameLevel"))
		assert.is_function(api.callbacks.OpenMap_ViewChanged)
		api.stitched = false
		map.providers[1]:RefreshAllData()
		assert.equals(1, #pins())
	end)

	it("prints one message when a draw fails", function()
		load(true)
		map.GetCanvas = function()
			error("boom")
		end
		map.providers[1]:RefreshAllData()
		map.providers[1]:RefreshAllData()
		local count = 0
		for _, line in ipairs(ctx.printed) do
			if line:find("map pin error", 1, true) then
				count = count + 1
			end
		end
		assert.equals(1, count)
	end)
end)
