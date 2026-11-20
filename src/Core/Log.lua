-- Core/Log.lua
--
-- Chat output. Print is for messages the user asked for; Debug/Info/Warn/Error are diagnostics
-- that only show at or above the chosen debug level (/gb debug, or the Options page).

---@type string, GirthBindNamespace
local ADDON_NAME, ns = ...
local Util = ns.Util

---@class GirthBindLog
local Log = {}
ns.Log = Log

---@alias GirthBindLogLevel "log"|"info"|"warning"|"error"|"none"

--- Levels in increasing severity; a message prints when its level is at or above the setting.
---@type GirthBindLogLevel[]
Log.LEVEL_ORDER = { "log", "info", "warning", "error", "none" }
Log.LEVELS = {}
for index, level in ipairs(Log.LEVEL_ORDER) do
    Log.LEVELS[level] = index
end
Log.DEFAULT_LEVEL = "none"

local LEVEL_COLORS = {
    log = Util.COLORS.GRAY,
    info = "ff66ccff",
    warning = "ffffcc00",
    error = Util.COLORS.RED,
}

local TAG = Util.Color(Util.COLORS.TAG, "[" .. ADDON_NAME .. "]")

local function Format(fmt, ...)
    if select("#", ...) > 0 then
        return tostring(fmt):format(...)
    end
    return tostring(fmt)
end

---@return GirthBindLogLevel
function Log.GetLevel()
    local level = ns.db and ns.db.global.debugLevel
    return Log.LEVELS[level or ""] and level or Log.DEFAULT_LEVEL
end

---@param level string
---@return boolean
function Log.IsValidLevel(level)
    return Log.LEVELS[level] ~= nil
end

--- A user-facing chat line: "[GirthBind] message".
function Log.Print(fmt, ...)
    print(TAG .. " " .. Format(fmt, ...))
end

--- A diagnostic line: "[GirthBind] - level - message", shown when level >= the setting.
---@param level GirthBindLogLevel
function Log.Write(level, fmt, ...)
    if Log.LEVELS[level] < Log.LEVELS[Log.GetLevel()] then
        return
    end
    print(("%s - %s - %s"):format(TAG, Util.Color(LEVEL_COLORS[level], level), Format(fmt, ...)))
end

function Log.Debug(fmt, ...)
    Log.Write("log", fmt, ...)
end

function Log.Info(fmt, ...)
    Log.Write("info", fmt, ...)
end

function Log.Warn(fmt, ...)
    Log.Write("warning", fmt, ...)
end

function Log.Error(fmt, ...)
    Log.Write("error", fmt, ...)
end
