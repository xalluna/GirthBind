-- Boots the addon inside the fake client: real LibStub/Ace3 libraries from libs/, stand-ins for
-- the UI-heavy AceConfig libraries, then every file the TOC lists, in TOC order.

local Wow = require("wow")

local Loader = {}

local LIBS = {
    "libs/LibStub/LibStub.lua",
    "libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
    "libs/AceAddon-3.0/AceAddon-3.0.lua",
    "libs/AceEvent-3.0/AceEvent-3.0.lua",
    "libs/AceConsole-3.0/AceConsole-3.0.lua",
    "libs/AceDB-3.0/AceDB-3.0.lua",
    "libs/AceLocale-3.0/AceLocale-3.0.lua",
}

--- Lua files the TOC loads, in order (embeds.xml is replaced by LIBS above).
---@return string[]
function Loader.TocFiles()
    local files = {}
    for line in io.lines("GirthBind.toc") do
        line = line:gsub("\r$", "")
        if line ~= "" and not line:match("^#") and line:match("%.lua$") then
            files[#files + 1] = (line:gsub("\\", "/"))
        end
    end
    return files
end

-- AceConfig needs AceGUI and real frames; tests only need what Options calls.
local function InstallFakeAceConfig(state)
    local AceConfig = LibStub:NewLibrary("AceConfig-3.0", 1)
    function AceConfig:RegisterOptionsTable(appName, options)
        state.optionsApp = appName
        state.optionsTable = options
    end
    local AceConfigDialog = LibStub:NewLibrary("AceConfigDialog-3.0", 1)
    function AceConfigDialog:AddToBlizOptions(appName, name)
        state.panel = CreateFrame("Frame", nil)
        state.panelName = name or appName
        return state.panel, "category-" .. appName
    end
    local AceConfigRegistry = LibStub:NewLibrary("AceConfigRegistry-3.0", 1)
    function AceConfigRegistry:NotifyChange(appName)
        state.notified = (state.notified or 0) + 1
        state.notifiedApp = appName
    end
end

---@class LoadOptions
---@field addonName string? Folder name (default "GirthBind")
---@field questieDB table? Fake LibQuestieDB to install
---@field savedVariables table? Initial SavedVariables table
---@field login boolean? Fire ADDON_LOADED/PLAYER_LOGIN (default true)
---@field addons table? Wow.Reset addons option
---@field before fun()? Runs after the fake client exists, before addon files load

--- Loads the addon. Returns its namespace, the fake client, and fake-AceConfig state.
---@param options LoadOptions?
function Loader.Load(options)
    options = options or {}
    local addonName = options.addonName or "GirthBind"
    Wow.Reset({ addons = options.addons })
    for _, path in ipairs(LIBS) do
        dofile(path)
    end
    local aceConfig = {}
    InstallFakeAceConfig(aceConfig)

    _G.LibQuestieDB = options.questieDB
    local svName = addonName:gsub("[^%w]", "") .. "DB"
    _G[svName] = options.savedVariables
    if options.before then
        options.before()
    end

    local ns = {}
    for _, path in ipairs(Loader.TocFiles()) do
        local chunk = assert(loadfile(path))
        chunk(addonName, ns)
    end
    if options.login ~= false then
        Wow.Login(addonName)
    end
    return ns, Wow, aceConfig
end

return Loader
