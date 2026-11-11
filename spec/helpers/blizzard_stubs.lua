-- Stubs for the Objective Tracker and Settings APIs. `rec` collects what the addon calls.
local function copyInto(target, source)
	for key, value in pairs(source) do
		target[key] = value
	end
	return target
end

return function()
	local rec = { containerCalls = {}, settings = {}, checkboxes = {}, categories = {} }
	rec.attached = true
	rec.managerError = false
	local manager = {}
	function manager.SetModuleContainer(_, module, container)
		if rec.managerError then
			error("boom")
		end
		table.insert(rec.containerCalls, { module, container })
		if rec.attached then
			module.container = container
		end
	end
	function manager.GetContainerForModule(_, module)
		return module.container
	end
	local trackerFrame = {}
	local globals = {
		ObjectiveTrackerModuleMixin = {},
		ObjectiveTrackerFrame = trackerFrame,
		ObjectiveTrackerManager = manager,
		CreateFromMixins = function(...)
			local out = {}
			for _, source in ipairs({ ... }) do
				copyInto(out, source)
			end
			return out
		end,
		Mixin = function(target, ...)
			for _, source in ipairs({ ... }) do
				copyInto(target, source)
			end
			return target
		end,
		EventUtil = {
			ContinueAfterAllEvents = function(fn)
				fn()
			end,
		},
		C_Timer = {
			After = function(_, fn)
				fn()
			end,
		},
		Enum = { UIMapType = { Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6 } },
		Settings = {
			VarType = { Boolean = "boolean" },
			RegisterVerticalLayoutCategory = function(name)
				local category = { name = name }
				table.insert(rec.categories, category)
				return category
			end,
			RegisterAddOnSetting = function(category, variable, key, tbl, varType, name, default)
				local setting = {
					category = category,
					variable = variable,
					key = key,
					tbl = tbl,
					varType = varType,
					name = name,
					default = default,
				}
				function setting:SetValueChangedCallback(fn)
					self.callback = fn
				end
				table.insert(rec.settings, setting)
				return setting
			end,
			CreateCheckbox = function(category, setting, tooltip)
				table.insert(rec.checkboxes, { category = category, setting = setting, tooltip = tooltip })
			end,
			RegisterAddOnCategory = function(category)
				rec.registered = category
			end,
		},
	}
	return globals, rec
end
