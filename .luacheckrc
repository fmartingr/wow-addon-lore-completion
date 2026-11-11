std = "lua51"
max_line_length = false
codes = true
exclude_files = { ".luarocks", "spec/helpers/*_fake.lua" }
globals = { "LoreCompletionDB", "LoreCompletionCharDB", "SLASH_LORECOMPLETION1", "SlashCmdList" }
read_globals = {
	"CreateFrame",
	"C_Map",
	"C_QuestLog",
	"UnitFactionGroup",
	"UnitClass",
	"UnitRace",
	"LibQuestieDB",
	"QuestDB",
	"ObjectiveTrackerFrame",
	"ObjectiveTrackerManager",
	"ObjectiveTrackerModuleMixin",
	"Settings",
	"ScrollUtil",
	"CreateScrollBoxListLinearView",
	"Mixin",
	"CreateFromMixins",
	"Enum",
	"GameFontNormal",
	"GameFontHighlight",
	"UIParent",
	"UISpecialFrames",
	"EventUtil",
	"NORMAL_FONT_COLOR",
	"tinsert",
	"wipe",
	"loadstring",
}
files["spec/"] = { std = "+busted" }
