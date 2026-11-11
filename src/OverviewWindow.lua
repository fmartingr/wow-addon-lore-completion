local _, ns = ...

ns.Overview = {}

local ICON = "Interface\\AddOns\\LoreCompletion\\assets\\icon.tga"
local CHECK = "Interface\\RaidFrame\\ReadyCheck-Ready"
local ROW_HEIGHT = 22
local CHAIN_INDENT = 14
local TAG_COLOR = "|cff69ccf0"

local frame, mapBox, questBox, messageText, hintText, namesCheck
local selectedMap

local function newScroll(parent, anchor, x1, y1, relPoint, x2, y2, rowInit)
	local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	box:SetPoint("TOPLEFT", anchor, "TOPLEFT", x1, y1)
	box:SetPoint("BOTTOMRIGHT", anchor, relPoint, x2, y2)
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 2, 0)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 2, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementFactory(function(factory)
		factory("Button", rowInit)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
	return box
end

local function ensureRow(button)
	if button.label then
		return
	end
	button.selected = button:CreateTexture(nil, "BACKGROUND")
	button.selected:SetAllPoints()
	button.selected:SetColorTexture(1, 0.82, 0, 0.18)
	button.line = button:CreateTexture(nil, "ARTWORK")
	button.line:SetColorTexture(1, 0.82, 0, 0.35)
	button.line:SetHeight(1)
	button.line:SetPoint("BOTTOMLEFT", 2, 0)
	button.line:SetPoint("BOTTOMRIGHT", -2, 0)
	button.check = button:CreateTexture(nil, "ARTWORK")
	button.check:SetSize(14, 14)
	button.check:SetTexture(CHECK)
	button.count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	button.count:SetPoint("RIGHT", -8, 0)
	button.count:SetJustifyH("RIGHT")
	button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	button.label:SetJustifyH("LEFT")
	button.label:SetWordWrap(false)
	button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
end

local function setShown(region, shown)
	if shown then
		region:Show()
	else
		region:Hide()
	end
end

-- The label is anchored on both sides, so a long name is cut at the count text and never overflows the row.
local function layoutRow(button, opts)
	button.label:SetFontObject(opts.header and "GameFontNormal" or "GameFontHighlight")
	button.label:ClearAllPoints()
	button.label:SetPoint("LEFT", opts.indent, 0)
	button.label:SetPoint("RIGHT", button.count, "LEFT", -6, 0)
	button.label:SetText(opts.text)
	button.count:SetText(opts.count or "")
	setShown(button.line, opts.header)
	setShown(button.check, opts.done)
	setShown(button.selected, opts.selected)
	button:EnableMouse(opts.clickable)
	if opts.done then
		button.check:ClearAllPoints()
		button.check:SetPoint("LEFT", opts.indent - 18, 0)
	end
	if not opts.clickable then
		button:SetScript("OnClick", nil)
	end
end

local function initMapRow(button, data)
	ensureRow(button)
	local model = ns.OverviewModel
	if data.kind == "group" then
		layoutRow(button, {
			text = data.title,
			count = model.CountText(data.done, data.total),
			indent = 6,
			header = true,
		})
		return
	end
	layoutRow(button, {
		text = data.map.name,
		count = model.MapCountText(data.map),
		indent = 18,
		clickable = true,
		selected = data.map.uiMapID == selectedMap,
	})
	button:SetScript("OnClick", function()
		selectedMap = data.map.uiMapID
		ns.Overview.Rebuild()
	end)
end

local function initQuestRow(button, data)
	ensureRow(button)
	if data.kind == "area" then
		layoutRow(button, {
			text = data.title,
			count = ns.OverviewModel.CountText(data.done, data.total),
			indent = 6,
			header = true,
		})
		return
	end
	local tags = data.tags ~= "" and (TAG_COLOR .. data.tags .. "|r") or ""
	layoutRow(button, {
		text = ns.OverviewModel.QuestRowText(data),
		count = tags,
		indent = 26 + (data.depth or 0) * CHAIN_INDENT,
		done = data.done,
		clickable = data.pinnable,
	})
	if data.pinnable then
		button:SetScript("OnClick", function()
			ns.Overview.TogglePin(data.id)
		end)
	end
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
			table.insert(rows, { kind = "group", title = group.title, done = group.done, total = group.total })
			for _, map in ipairs(group.maps) do
				table.insert(rows, { kind = "map", map = map })
			end
		end
		mapBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
	end
	local quests = {}
	if selectedMap then
		local player = ns.QuestLevel.Player(ns.env, ns.playerLevel)
		quests = ns.OverviewModel.QuestGroups(ns.env, index, state, selectedMap, LoreCompletionDB.showNames, player)
		ns.GiverModel.Annotate(ns.givers, quests, LoreCompletionCharDB.pinned)
	end
	setShown(hintText, not selectedMap and not message)
	questBox:SetDataProvider(CreateDataProvider(quests), ScrollBoxConstants.RetainScrollPosition)
end

-- A click pins the quest giver on the world map. A second click removes the pin.
function ns.Overview.TogglePin(questID)
	local pinned = LoreCompletionCharDB.pinned
	pinned[questID] = not pinned[questID] or nil
	ns.RunRefresh()
end

function ns.Overview.Rebuild()
	if frame and frame:IsShown() then
		rebuild()
	end
end

local function setPortrait(target)
	if target.SetPortraitToAsset then
		target:SetPortraitToAsset(ICON)
	elseif target.GetPortrait then
		target:GetPortrait():SetTexture(ICON)
	elseif target.portrait then
		target.portrait:SetTexture(ICON)
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
	setPortrait(frame)
	tinsert(UISpecialFrames, "LoreCompletionOverview")

	-- The Inset is the dark content panel of the template; its border sits below the scroll boxes.
	local inset = frame.Inset or frame
	mapBox = newScroll(frame, inset, 6, -6, "BOTTOMLEFT", 284, 6, initMapRow)
	questBox = newScroll(frame, inset, 314, -6, "BOTTOMRIGHT", -24, 6, initQuestRow)

	messageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	messageText:SetPoint("TOPLEFT", 12, -70)

	hintText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	hintText:SetPoint("CENTER", questBox, "CENTER")
	hintText:SetText(ns.L["Select a map"])

	namesCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	namesCheck:SetPoint("TOPLEFT", 316, -34)
	namesCheck.text = namesCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	namesCheck.text:SetPoint("LEFT", namesCheck, "RIGHT", 2, 0)
	namesCheck.text:SetText(ns.L["Show names"])
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
