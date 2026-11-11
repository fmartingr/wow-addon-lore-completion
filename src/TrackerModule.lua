local _, ns = ...

local GOLD = { 1, 0.82, 0 }

ns.TrackerModule = {}

local mixin = CreateFromMixins(ObjectiveTrackerModuleMixin)
mixin.headerText = ns.L["Lore"]
ns.TrackerModule.mixin = mixin

function mixin:LayoutContents()
	local view = ns.TrackerModel.Build(ns.env, ns.index, ns.state, LoreCompletionDB)
	if not view then
		return
	end
	local block = self:GetBlock("lore")
	block:SetHeader(view.title)
	block:AddObjective("progress", view.text)
	local bar = block:AddProgressBar("progress")
	bar:SetPercent(view.percent)
	local statusBar = bar.Bar
	if not bar.loreDefaultColor then
		bar.loreDefaultColor = { statusBar:GetStatusBarColor() }
	end
	local color = view.complete and GOLD or bar.loreDefaultColor
	statusBar:SetStatusBarColor(color[1], color[2], color[3])
	block.uiMapID = view.uiMapID
	return self:LayoutBlock(block)
end

function mixin.OnBlockHeaderClick(_, block)
	ns.Overview.OpenMap(block.uiMapID)
end

local function attach(frame)
	local ok = pcall(ObjectiveTrackerManager.SetModuleContainer, ObjectiveTrackerManager, frame, ObjectiveTrackerFrame)
	return ok and ObjectiveTrackerManager:GetContainerForModule(frame) == ObjectiveTrackerFrame
end

local function register()
	local frame = CreateFrame("Frame", "LoreCompletionTrackerModule", nil, "ObjectiveTrackerModuleTemplate")
	Mixin(frame, mixin)
	frame:SetHeader(ns.L["Lore"])
	frame.uiOrder = 0
	ns.trackerFrame = frame
	-- Blizzard may add the container after this callback runs, so one retry on the next frame is allowed.
	if attach(frame) then
		return
	end
	C_Timer.After(0, function()
		if not attach(frame) then
			print(ns.L["LoreCompletion: tracker module not available"])
		end
	end)
end

local function markDirty()
	if ns.trackerFrame then
		ns.trackerFrame:MarkDirty()
	end
end

table.insert(ns.onReady, function()
	EventUtil.ContinueAfterAllEvents(register, "PLAYER_ENTERING_WORLD", "VARIABLES_LOADED")
	for _, event in ipairs({ "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD" }) do
		ns.Events.On(event, markDirty)
	end
	ns.OnRefresh(markDirty)
end)
