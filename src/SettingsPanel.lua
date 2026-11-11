local _, ns = ...

local OPTIONS = {
	{
		key = "showTracker",
		label = "Show tracker module",
		default = true,
		tooltip = "Show the Lore module in the Objective Tracker.",
	},
	{
		key = "hideWhenComplete",
		label = "Hide when complete",
		default = false,
		tooltip = "Hide the module on a map where all quests are done.",
	},
}

ns.SettingsPanel = { OPTIONS = OPTIONS }

table.insert(ns.onReady, function()
	local category = Settings.RegisterVerticalLayoutCategory("LoreCompletion")
	for _, option in ipairs(OPTIONS) do
		local setting = Settings.RegisterAddOnSetting(
			category,
			"LoreCompletion_" .. option.key,
			option.key,
			LoreCompletionDB,
			Settings.VarType.Boolean,
			option.label,
			option.default
		)
		Settings.CreateCheckbox(category, setting, option.tooltip)
		setting:SetValueChangedCallback(ns.RunRefresh)
	end
	Settings.RegisterAddOnCategory(category)
end)
