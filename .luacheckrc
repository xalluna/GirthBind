-- luacheck configuration (https://luacheck.readthedocs.io). Run: scripts/test.ps1, or CI.
std = "lua51"
max_line_length = 140
codes = true
exclude_files = { "libs/", "types/", ".luarocks/", ".install/", "lua_modules/" } -- types/ is LuaLS-only

ignore = {
    "212/self", -- unused self in methods (AceAddon event handlers)
    "212/_.*", -- unused arguments named _ or _x
    "211/_.*", -- unused locals named _ or _x
    "432/self", -- shadowing upvalue self in nested methods
}

-- WoW client globals the addon reads. Keep sorted; add new API here when lint flags it.
read_globals = {
    "C_AddOns", "C_Map", "C_QuestLog", "C_Timer",
    "CANCEL", "CreateDataProvider", "CreateFrame", "CreateMacro", "CreateScrollBoxListLinearView",
    "EditMacro", "EllesmereUI", "EventRegistry",
    "GameTooltip", "GameTooltip_AddNormalLine", "GameTooltip_SetTitle",
    "GetMacroIndexByName", "GetMacroInfo", "GetNumMacros", "GetQuestDifficultyColor",
    "InCombatLockdown", "LibQuestieDB", "LibStub", "MAX_ACCOUNT_MACROS", "Menu", "PickupMacro",
    "QuestieLoader", "ScrollUtil", "Settings",
    "UIParent", "UISpecialFrames", "UnitExists", "UnitGUID", "UnitName",
    "debugprofilestop", "geterrorhandler", "issecretvalue", "strlenutf8", "strsplit",
}

files["locales/"] = { max_line_length = false }

files["tests/"] = {
    std = "+busted",
    -- The fake client installs WoW globals on purpose.
    ignore = { "111", "112", "113", "121", "122", "131", "142", "143" },
    max_line_length = false,
}
