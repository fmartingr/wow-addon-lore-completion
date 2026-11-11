local _, ns = ...

ns.Overview = {}

local frame, mapBox, questBox, messageText, namesCheck
local selectedMap

local function newScroll(parent, x1, y1, relPoint, x2, y2, rowInit)
	local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	box:SetPoint("TOPLEFT", parent, "TOPLEFT", x1, y1)
	box:SetPoint("BOTTOMRIGHT", parent, relPoint, x2, y2)
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 2, 0)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 2, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(20)
	view:SetElementFactory(function(factory)
		factory("Button", rowInit)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
	return box
end

local function ensureText(button)
	if not button.label then
		button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		button.label:SetPoint("LEFT", 6, 0)
		button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	end
	return button.label
end

local function initMapRow(button, data)
	local label = ensureText(button)
	if data.kind == "group" then
		label:SetText(data.title)
		button:SetScript("OnClick", nil)
	else
		label:SetText(ns.OverviewModel.MapRowText(data.map))
		button:SetScript("OnClick", function()
			selectedMap = data.map.uiMapID
			ns.Overview.Rebuild()
		end)
	end
end

local function initQuestRow(button, data)
	ensureText(button):SetText(ns.OverviewModel.QuestRowText(data))
end

local function rebuild()
	local index, state = ns.index, ns.state
	local message = ns.OverviewModel.Message(index)
	if message then
		messageText:SetText(message)
		messageText:Show()
		mapBox:Hide()
	else
		messageText:Hide()
		mapBox:Show()
		local rows = {}
		for _, group in ipairs(ns.OverviewModel.Groups(ns.env, index, state)) do
			table.insert(rows, { kind = "group", title = group.title })
			for _, map in ipairs(group.maps) do
				table.insert(rows, { kind = "map", map = map })
			end
		end
		mapBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
	end
	local quests = {}
	if selectedMap then
		quests = ns.OverviewModel.Quests(index, state, selectedMap, LoreCompletionDB.showNames)
	end
	questBox:SetDataProvider(CreateDataProvider(quests), ScrollBoxConstants.RetainScrollPosition)
end

function ns.Overview.Rebuild()
	if frame and frame:IsShown() then
		rebuild()
	end
end

local function ensureFrame()
	if frame then
		return
	end
	frame = CreateFrame("Frame", "LoreCompletionOverview", UIParent, "ButtonFrameTemplate")
	frame:SetSize(720, 480)
	frame:SetPoint("CENTER")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetTitle("LoreCompletion")
	tinsert(UISpecialFrames, "LoreCompletionOverview")

	mapBox = newScroll(frame, 12, -64, "BOTTOMLEFT", 290, 12, initMapRow)
	questBox = newScroll(frame, 320, -64, "BOTTOMRIGHT", -28, 12, initQuestRow)

	messageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	messageText:SetPoint("TOPLEFT", 12, -70)

	namesCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	namesCheck:SetPoint("TOPLEFT", 316, -34)
	namesCheck.text = namesCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	namesCheck.text:SetPoint("LEFT", namesCheck, "RIGHT", 2, 0)
	namesCheck.text:SetText("Show names")
	namesCheck:SetChecked(LoreCompletionDB.showNames)
	namesCheck:SetScript("OnClick", function(self)
		LoreCompletionDB.showNames = self:GetChecked() and true or false
		ns.Overview.Rebuild()
	end)

	frame:SetScript("OnShow", function()
		namesCheck:SetChecked(LoreCompletionDB.showNames)
		rebuild()
	end)
	-- ButtonFrameTemplate frames start shown, so the first Toggle would hide them.
	frame:Hide()
end

function ns.Overview.Toggle()
	ensureFrame()
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

function ns.Overview.OpenMap(uiMapID)
	ensureFrame()
	selectedMap = nil
	if uiMapID and #ns.index:QuestsOn(uiMapID) > 0 then
		selectedMap = uiMapID
	end
	if frame:IsShown() then
		rebuild()
	else
		frame:Show()
	end
end

ns.OnRefresh(ns.Overview.Rebuild)

table.insert(ns.onReady, function()
	SLASH_LORECOMPLETION1 = "/lore"
	SlashCmdList.LORECOMPLETION = function()
		ns.Overview.Toggle()
	end
end)
