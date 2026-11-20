-- A minimal fake WoW client for running the addon (and the real Ace3 libraries) under busted.
-- Wow.Reset() installs fresh globals; tests then drive events, timers, combat, macros and units.

local Wow = {}

local function noop() end

-- WoW's xpcall passes extra arguments to the function (Lua 5.2 style); stock 5.1's doesn't,
-- and AceAddon relies on it to call OnInitialize/OnEnable with self.
local rawxpcall = xpcall
local function WowXpcall(fn, handler, ...)
    local count, args = select("#", ...), { ... }
    return rawxpcall(function()
        return fn(unpack(args, 1, count))
    end, handler)
end

--------------------------------------------------------------------------------------------
-- Frames
--------------------------------------------------------------------------------------------

local FrameMethods = {}
FrameMethods.__index = FrameMethods

function FrameMethods:RegisterEvent(event)
    self._events[event] = true
end
function FrameMethods:UnregisterEvent(event)
    self._events[event] = nil
end
function FrameMethods:UnregisterAllEvents()
    self._events = {}
end
function FrameMethods:IsEventRegistered(event)
    return self._events[event] == true
end
function FrameMethods:SetScript(name, fn)
    self._scripts[name] = fn
end
function FrameMethods:GetScript(name)
    return self._scripts[name]
end
function FrameMethods:HookScript(name, fn)
    local previous = self._scripts[name]
    self._scripts[name] = function(...)
        if previous then
            previous(...)
        end
        fn(...)
    end
end
-- Like the client: frames start shown, and OnShow/OnHide fire only on a change.
function FrameMethods:Show()
    if self._shown then
        return
    end
    self._shown = true
    if self._scripts.OnShow then
        self._scripts.OnShow(self)
    end
end
function FrameMethods:Hide()
    if not self._shown then
        return
    end
    self._shown = false
    if self._scripts.OnHide then
        self._scripts.OnHide(self)
    end
end
function FrameMethods:IsShown()
    return self._shown
end
function FrameMethods:IsMouseOver()
    return self._mouseOver == true
end
function FrameMethods:SetText(text)
    self._text = text
end
function FrameMethods:GetText()
    return self._text
end
local NewFrame
function FrameMethods:CreateFontString()
    return NewFrame("FontString")
end
function FrameMethods:CreateTexture()
    return NewFrame("Texture")
end

-- Any other widget method is accepted and does nothing.
setmetatable(FrameMethods, {
    __index = function()
        return noop
    end,
})

function NewFrame(frameType, name)
    local frame = setmetatable({
        _type = frameType,
        _name = name,
        _events = {},
        _scripts = {},
        _shown = true,
    }, FrameMethods)
    Wow.frames[#Wow.frames + 1] = frame
    if name then
        _G[name] = frame
    end
    return frame
end

--- Delivers an event to every frame registered for it.
function Wow.FireEvent(event, ...)
    for _, frame in ipairs(Wow.frames) do
        if frame._events[event] and frame._scripts.OnEvent then
            frame._scripts.OnEvent(frame, event, ...)
        end
    end
end

--------------------------------------------------------------------------------------------
-- Timers
--------------------------------------------------------------------------------------------

--- Runs every pending C_Timer callback; callbacks scheduled meanwhile run on the next call.
---@return integer ran
function Wow.RunTimers()
    local due = Wow.timers
    Wow.timers = {}
    for _, timer in ipairs(due) do
        if not timer.cancelled then
            timer.callback()
        end
    end
    return #due
end

--- Runs timers until none are left (bounded, to catch runaway loops).
function Wow.FlushTimers()
    for _ = 1, 10000 do
        if Wow.RunTimers() == 0 then
            return
        end
    end
    error("timers never settled")
end

--------------------------------------------------------------------------------------------
-- Macros
--------------------------------------------------------------------------------------------

local function MacroIndex(name)
    for index, macro in ipairs(Wow.macros) do
        if macro.name == name then
            return index
        end
    end
    return 0
end

--------------------------------------------------------------------------------------------
-- Reset
--------------------------------------------------------------------------------------------

---@param options { addons: table<string, { loaded: boolean?, enabled: boolean?, loadable: boolean? }>? }?
function Wow.Reset(options)
    options = options or {}
    -- Slash commands and named frames are globals; drop the previous run's.
    for key in pairs(_G) do
        if type(key) == "string" and key:match("^SLASH_") then
            _G[key] = nil
        end
    end
    for _, frame in ipairs(Wow.frames or {}) do
        if frame._name then
            _G[frame._name] = nil
        end
    end
    Wow.frames = {}
    Wow.timers = {}
    Wow.chat = {}
    Wow.errors = {}
    Wow.macros = {}
    Wow.cursor = nil
    Wow.inCombat = false
    Wow.loggedIn = false
    Wow.clock = 0
    Wow.target = nil
    Wow.questLog = {}
    Wow.areas = { [12] = "Elwynn Forest", [40] = "Westfall" }
    Wow.addons = options.addons or {}
    Wow.metadata = { Version = "1.0.0-test" }
    Wow.openedCategory = nil
    Wow.menuCallbacks = {}

    -- Lua/WoW string and table helpers
    _G.xpcall = WowXpcall
    _G.strsplit = function(delimiter, text)
        local parts = {}
        for part in (text .. delimiter):gmatch("(.-)" .. delimiter:gsub("%p", "%%%0")) do
            parts[#parts + 1] = part
        end
        return unpack(parts)
    end
    _G.strtrim = function(text)
        return (text:match("^%s*(.-)%s*$"))
    end
    _G.strmatch, _G.strfind, _G.strsub = string.match, string.find, string.sub
    _G.strlower, _G.strupper, _G.strlen, _G.format, _G.gsub = string.lower, string.upper, string.len, string.format, string.gsub
    _G.strlenutf8 = nil
    _G.tinsert, _G.tremove, _G.tconcat = table.insert, table.remove, table.concat
    _G.wipe = function(t)
        for key in pairs(t) do
            t[key] = nil
        end
        return t
    end
    _G.tostringall = function(...)
        local out = {}
        for i = 1, select("#", ...) do
            out[i] = tostring((select(i, ...)))
        end
        return unpack(out, 1, select("#", ...))
    end
    _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        Wow.chat[#Wow.chat + 1] = table.concat(parts, " ")
    end
    _G.geterrorhandler = function()
        return function(err)
            Wow.errors[#Wow.errors + 1] = tostring(err)
        end
    end
    _G.securecallfunction = function(fn, ...)
        local ok, err = pcall(fn, ...)
        if not ok then
            geterrorhandler()(err)
        end
    end
    _G.issecretvalue = nil
    _G.debugprofilestop = function()
        Wow.clock = Wow.clock + 1
        return Wow.clock
    end
    _G.GetTime = function()
        return Wow.clock / 1000
    end

    -- Frames and UI globals
    _G.CreateFrame = function(frameType, name)
        return NewFrame(frameType, name)
    end
    _G.UIParent = NewFrame("Frame", "UIParent")
    _G.UISpecialFrames = {}
    _G.SlashCmdList = {}
    _G.hash_SlashCmdList = {}
    _G.ChatFrame_ImportListToHash = nil
    _G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) Wow.chat[#Wow.chat + 1] = text end }
    _G.CANCEL = "Cancel"
    _G.GameTooltip = setmetatable({}, { __index = function() return noop end })
    _G.GameTooltip_SetTitle = noop
    _G.GameTooltip_AddNormalLine = noop

    -- Session and character
    _G.IsLoggedIn = function()
        return Wow.loggedIn
    end
    _G.GetLocale = function()
        return "enUS"
    end
    _G.GetRealmName = function()
        return "TestRealm"
    end
    _G.GetCurrentRegion = function()
        return 1
    end
    _G.GetCurrentRegionName = function()
        return "US"
    end
    _G.UnitNameUnmodified = function()
        return "Tester"
    end
    _G.UnitClass = function()
        return "Warrior", "WARRIOR", 1
    end
    _G.UnitRace = function()
        return "Human", "Human", 1
    end
    _G.UnitFactionGroup = function()
        return "Alliance", "Alliance"
    end

    -- Units: Wow.target = { name =, guid = } or nil
    _G.UnitExists = function(unit)
        return unit == "player" or (unit == "target" and Wow.target ~= nil)
    end
    _G.UnitName = function(unit)
        if unit == "player" then
            return "Tester"
        end
        return Wow.target and Wow.target.name
    end
    _G.UnitGUID = function(unit)
        if unit == "player" then
            return "Player-1-00000001"
        end
        return Wow.target and Wow.target.guid
    end

    -- Combat
    _G.InCombatLockdown = function()
        return Wow.inCombat
    end

    -- Timers
    _G.C_Timer = {
        After = function(_, callback)
            Wow.timers[#Wow.timers + 1] = { callback = callback }
        end,
        NewTimer = function(_, callback)
            local timer = { callback = callback }
            function timer:Cancel()
                self.cancelled = true
            end
            Wow.timers[#Wow.timers + 1] = timer
            return timer
        end,
    }

    -- Addons
    local function Addon(name)
        return Wow.addons[name] or {}
    end
    _G.C_AddOns = {
        IsAddOnLoaded = function(name)
            return Addon(name).loaded == true
        end,
        IsAddOnLoadable = function(name)
            local addon = Addon(name)
            return addon.loadable ~= false and addon.enabled == true, nil
        end,
        GetAddOnEnableState = function(name)
            return Addon(name).enabled and 2 or 0
        end,
        GetAddOnMetadata = function(_, field)
            return Wow.metadata[field]
        end,
    }

    -- Macros
    _G.MAX_ACCOUNT_MACROS = 120
    _G.GetNumMacros = function()
        return #Wow.macros, 0
    end
    _G.GetMacroIndexByName = MacroIndex
    _G.GetMacroInfo = function(index)
        local macro = Wow.macros[index]
        if macro then
            return macro.name, macro.icon, macro.body
        end
    end
    _G.CreateMacro = function(name, icon, body, perCharacter)
        assert(not Wow.inCombat, "CreateMacro is protected in combat")
        assert(not perCharacter, "GirthBind only makes account macros")
        assert(#body <= 255, "macro body too long")
        Wow.macros[#Wow.macros + 1] = { name = name, icon = icon, body = body }
        return #Wow.macros
    end
    _G.EditMacro = function(index, name, icon, body)
        assert(not Wow.inCombat, "EditMacro is protected in combat")
        local macro = assert(Wow.macros[index], "no macro at index " .. tostring(index))
        assert(#body <= 255, "macro body too long")
        macro.name, macro.icon, macro.body = name or macro.name, icon or macro.icon, body or macro.body
        return index
    end
    _G.PickupMacro = function(index)
        assert(Wow.macros[index], "no macro at index " .. tostring(index))
        Wow.cursor = { macro = index }
    end

    -- Maps and quests
    _G.C_Map = {
        GetAreaInfo = function(areaId)
            return Wow.areas[areaId]
        end,
    }
    _G.C_QuestLog = {
        GetNumQuestLogEntries = function()
            return #Wow.questLog
        end,
        GetInfo = function(index)
            return Wow.questLog[index]
        end,
        IsComplete = function(questId)
            for _, info in ipairs(Wow.questLog) do
                if info.questID == questId then
                    return info.complete == true
                end
            end
            return false
        end,
        IsOnQuest = function(questId)
            for _, info in ipairs(Wow.questLog) do
                if info.questID == questId then
                    return true
                end
            end
            return false
        end,
        GetTitleForQuestID = function(questId)
            for _, info in ipairs(Wow.questLog) do
                if info.questID == questId then
                    return info.title
                end
            end
            return nil
        end,
    }
    _G.GetQuestDifficultyColor = function()
        return { r = 1, g = 1, b = 0 }
    end

    -- Settings and menus
    _G.Settings = {
        OpenToCategory = function(id)
            Wow.openedCategory = id
        end,
    }
    _G.Menu = {
        ModifyMenu = function(tag, callback)
            Wow.menuCallbacks[tag] = callback
            return { Unregister = noop }
        end,
    }
    _G.EventRegistry = {
        callbacks = {},
        RegisterCallbackWithHandle = function(self, event, callback)
            self.callbacks[event] = callback
            return { Unregister = noop }
        end,
        TriggerEvent = function(self, event, ...)
            if self.callbacks[event] then
                self.callbacks[event](nil, ...)
            end
        end,
    }

    -- Optional addons start absent
    _G.LibQuestieDB = nil
    _G.QuestieLoader = nil
    _G.EllesmereUI = nil
    _G.LibStub = nil
end

--- Logs in: fires the events AceAddon uses to initialize and enable addons.
---@param addonName string
function Wow.Login(addonName)
    Wow.FireEvent("ADDON_LOADED", addonName)
    Wow.loggedIn = true
    Wow.FireEvent("PLAYER_LOGIN")
    Wow.FireEvent("PLAYER_ENTERING_WORLD", true, false)
end

--- The last chat line, or nil.
---@return string?
function Wow.LastChat()
    return Wow.chat[#Wow.chat]
end

--- Every chat line joined, with color codes stripped, for substring assertions.
---@return string
function Wow.ChatText()
    local text = table.concat(Wow.chat, "\n")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return text
end

return Wow
