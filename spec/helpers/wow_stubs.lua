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
	for _, method in ipairs({ "SetPoint", "Show", "Hide", "SetText", "SetSize", "SetMovable", "EnableMouse" }) do
		frame[method] = function(self, ...)
			table.insert(self.calls, { method, ... })
		end
	end
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
	}
	return globals, ctx
end

return M
