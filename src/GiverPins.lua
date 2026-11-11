local _, ns = ...

ns.GiverPins = {}

local ICON = "Interface\\AddOns\\LoreCompletion\\assets\\giver.tga"
local PIN_SIZE = 18
local TITLE_COLOR = { 1, 0.82, 0 }

local provider, container
local pool, used = {}, 0

local function showTooltip(pin)
	local data = pin.data
	GameTooltip:SetOwner(pin, "ANCHOR_RIGHT")
	GameTooltip:AddLine(data.title or "?", TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3])
	for _, line in ipairs(data.lines) do
		GameTooltip:AddLine(line, 1, 1, 1)
	end
	GameTooltip:Show()
end

local function newPin()
	local pin = CreateFrame("Frame", nil, container)
	pin.icon = pin:CreateTexture(nil, "OVERLAY")
	pin.icon:SetAllPoints()
	pin.icon:SetTexture(ICON)
	pin:EnableMouse(true)
	pin:SetScript("OnEnter", showTooltip)
	pin:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return pin
end

local function clear()
	for i = 1, used do
		pool[i]:Hide()
	end
	used = 0
end

-- A plain child of the canvas sits under the map art, so the container takes the level of the game's area pins.
local function pinLevel(map)
	if not map.GetPinFrameLevelsManager then
		return nil
	end
	local ok, level = pcall(function()
		return map:GetPinFrameLevelsManager():GetValidFrameLevel("PIN_FRAME_LEVEL_AREA_POI")
	end)
	return ok and type(level) == "number" and level or nil
end

-- OpenMap's stitched map shows the zones around the map it sits on, so a pin of any zone can be in view.
local function stitched()
	local api = OpenMapAPI
	if api and api.IsStitched and api.IsStitched() and api.WorldFromMap and api.MapFromWorld then
		return api
	end
end

-- The position of a pin on the canvas of the map shown: 0..1 inside its rectangle, past it outside.
local function canvasPoint(api, hostID, data)
	if not api or data.uiMapID == hostID then
		return data.x, data.y
	end
	local u, v = api.WorldFromMap(data.uiMapID, data.x, data.y)
	if u then
		return api.MapFromWorld(hostID, u, v)
	end
end

local function draw()
	clear()
	local map = provider and provider:GetMap()
	if not (map and map:IsShown()) then
		return
	end
	local canvas = map:GetCanvas()
	if not container or container:GetParent() ~= canvas then
		container = CreateFrame("Frame", nil, canvas)
		container:SetAllPoints(canvas)
		pool = {}
	end
	local api = stitched()
	local level = pinLevel(map)
	-- The stitched art sits over the game's pin levels, so the pins go above the top of the art.
	if api and api.ArtTopLevel and api.ArtTopLevel() then
		level = math.max(level or 0, api.ArtTopLevel() + 1)
	end
	if level then
		container:SetFrameLevel(level)
	end
	container:Show()
	local player = ns.QuestLevel.Player(ns.env, ns.playerLevel)
	local hostID = map:GetMapID()
	local pins = ns.GiverModel.Pins(
		ns.givers,
		ns.state,
		not api and hostID or nil,
		player,
		LoreCompletionDB.showNames,
		LoreCompletionCharDB.pinned
	)
	local w, h = canvas:GetSize()
	-- The canvas grows when the map zooms in, so the pin size divides by the scale to stay the same on screen.
	local size = PIN_SIZE / (map.GetCanvasScale and map:GetCanvasScale() or 1)
	for _, data in ipairs(pins) do
		local x, y = canvasPoint(api, hostID, data)
		if x and y then
			used = used + 1
			local pin = pool[used] or newPin()
			pool[used] = pin
			pin.data = data
			pin:SetSize(size, size)
			pin:ClearAllPoints()
			pin:SetPoint("CENTER", container, "TOPLEFT", x * w, -y * h)
			pin.icon:SetDesaturated(data.dim)
			pin:Show()
		end
	end
end

local function safeDraw()
	local ok, err = pcall(draw)
	if not ok and not ns.GiverPins.failed then
		ns.GiverPins.failed = true
		print(ns.L["LoreCompletion: map pin error: %s"]:format(tostring(err)))
	end
end

ns.GiverPins.Draw = safeDraw

local function listenOpenMap()
	local api = OpenMapAPI
	if ns.GiverPins.openMap or not (api and api.RegisterCallback) then
		return
	end
	ns.GiverPins.openMap = true
	api.RegisterCallback(ns.GiverPins, "OpenMap_StitchedChanged", safeDraw)
	api.RegisterCallback(ns.GiverPins, "OpenMap_ViewChanged", safeDraw)
end

local function attach()
	listenOpenMap()
	if provider or not (WorldMapFrame and WorldMapFrame.AddDataProvider and MapCanvasDataProviderMixin) then
		return
	end
	provider = CreateFromMixins(MapCanvasDataProviderMixin)
	provider.OnMapChanged = safeDraw
	provider.RefreshAllData = safeDraw
	provider.OnCanvasScaleChanged = safeDraw
	provider.OnCanvasSizeChanged = safeDraw
	provider.RemoveAllData = clear
	WorldMapFrame:AddDataProvider(provider)
end

table.insert(ns.onReady, function()
	-- The world map can load after this addon, so later events try to attach again.
	attach()
	ns.Events.On("ADDON_LOADED", attach)
	ns.Events.On("PLAYER_ENTERING_WORLD", attach)
	ns.OnRefresh(safeDraw)
end)
