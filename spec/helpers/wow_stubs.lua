-- Fresh WoW stub globals for each test. The context records frames and printed lines.
local M = {}

local function newFrame(ctx, frameType, name, parent, template)
	local frame = {
		frameType = frameType,
		name = name,
		parent = parent,
		template = template,
		calls = {},
		scripts = {},
		events = {},
		shown = true, -- real frames start shown
	}
	function frame:RegisterEvent(event)
		self.events[event] = true
		table.insert(self.calls, { "RegisterEvent", event })
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
		table.insert(self.calls, { "UnregisterEvent", event })
	end
	function frame:SetScript(kind, fn)
		self.scripts[kind] = fn
		table.insert(self.calls, { "SetScript", kind })
	end
	function frame:Fire(event, ...)
		return self.scripts.OnEvent(self, event, ...)
	end
	function frame:Show()
		self.shown = true
		table.insert(self.calls, { "Show" })
		if self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end
	function frame:Hide()
		self.shown = false
		table.insert(self.calls, { "Hide" })
	end
	function frame:IsShown()
		return self.shown == true
	end
	function frame:SetChecked(value)
		self.checked = value
	end
	function frame:GetChecked()
		return self.checked
	end
	function frame:SetDataProvider(provider)
		self.data = provider.data
		table.insert(self.calls, { "SetDataProvider" })
	end
	-- Any other CamelCase method records the call and returns a child stub, so glue code runs unchanged.
	setmetatable(frame, {
		__index = function(_, key)
			if type(key) == "string" and key:match("^%u") then
				return function(owner, ...)
					table.insert(owner.calls, { key, ... })
					return newFrame(ctx, "Child", nil, owner)
				end
			end
		end,
	})
	table.insert(ctx.frames, frame)
	return frame
end

function M.new()
	local ctx = { frames = {}, printed = {} }
	local globals = {
		CreateFrame = function(frameType, name, parent, template)
			return newFrame(ctx, frameType, name, parent, template)
		end,
		C_Map = {
			GetBestMapForUnit = function()
				return nil
			end,
			GetMapInfo = function()
				return nil
			end,
			GetAreaInfo = function()
				return nil
			end,
		},
		C_QuestLog = {
			IsQuestFlaggedCompleted = function()
				return false
			end,
		},
		UnitFactionGroup = function()
			return "Alliance", "Alliance"
		end,
		UnitClass = function()
			return "Warrior", "WARRIOR", 1
		end,
		UnitRace = function()
			return "Human", "Human", 1
		end,
		print = function(...)
			table.insert(ctx.printed, table.concat({ ... }, " "))
		end,
		SlashCmdList = {},
		UIParent = {},
		ScrollBoxConstants = { RetainScrollPosition = true },
		UISpecialFrames = {},
		tinsert = table.insert,
		CreateDataProvider = function(data)
			return { data = data }
		end,
		CreateScrollBoxListLinearView = function()
			local view = { calls = {} }
			return setmetatable(view, {
				__index = function(self, key)
					return function(_, ...)
						table.insert(self.calls, { key, ... })
					end
				end,
			})
		end,
		ScrollUtil = {
			InitScrollBoxListWithScrollBar = function() end,
		},
	}
	return globals, ctx
end

return M
