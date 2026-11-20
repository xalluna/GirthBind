-- Core/Util.lua
--
-- Small, dependency-free helpers shared by every module.

---@type string, GirthBindNamespace
local _, ns = ...

---@class GirthBindUtil
local Util = {}
ns.Util = Util

Util.COLORS = {
    TAG = "ff33ff99",
    GRAY = "ff9d9d9d",
    GOLD = "ffffd100",
    WHITE = "ffffffff",
    GREEN = "ff20ff20",
    RED = "ffff4040",
    ORANGE = "ffff8000",
}

--- Wraps text in a WoW color escape.
---@param color string 8-digit ARGB hex, usually from Util.COLORS
---@param text any
---@return string
function Util.Color(color, text)
    return "|c" .. color .. tostring(text) .. "|r"
end

--- Midnight-era clients hand addons "secret values" for unit identity in combat and restricted
--- content. A secret value can't be compared or tested, so check before touching one.
---@param value any
---@return boolean
function Util.IsSecret(value)
    local issecret = _G.issecretvalue
    return issecret ~= nil and issecret(value) and true or false
end

--- The NPC ID in a creature GUID, or nil for players and other unit types.
--- Creature GUID: Creature-0-[server]-[instance]-[zone]-[npcId]-[spawn]
---@param guid string?
---@return integer?
function Util.ParseNpcId(guid)
    if type(guid) ~= "string" then
        return nil
    end
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if unitType == "Creature" or unitType == "Vehicle" or unitType == "Pet" then
        return tonumber(npcId)
    end
    return nil
end

---@param text string?
---@return string
function Util.Trim(text)
    return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

--- Trims, then removes one pair of matching surrounding quotes ("Name" or 'Name').
---@param text string?
---@return string
function Util.Unquote(text)
    local trimmed = Util.Trim(text)
    local inner = trimmed:match('^"(.*)"$') or trimmed:match("^'(.*)'$")
    return inner and Util.Trim(inner) or trimmed
end

--- Character count for UTF-8 text (macro name limits count characters, not bytes).
---@param text string
---@return integer
function Util.Utf8Len(text)
    local strlenutf8 = _G.strlenutf8
    if strlenutf8 then
        return strlenutf8(text)
    end
    local _, count = text:gsub("[^\128-\191]", "")
    return count
end

--- "12", "10-12", or nil when neither bound is known.
---@param minLevel integer?
---@param maxLevel integer?
---@return string?
function Util.FormatLevelRange(minLevel, maxLevel)
    if not minLevel and not maxLevel then
        return nil
    end
    minLevel = minLevel or maxLevel
    maxLevel = maxLevel or minLevel
    if minLevel == maxLevel then
        return tostring(minLevel)
    end
    return ("%d-%d"):format(minLevel, maxLevel)
end

--- The display name of an AreaID, or nil when the client doesn't know it.
---@param areaId integer?
---@return string?
function Util.GetAreaName(areaId)
    if type(areaId) ~= "number" or areaId <= 0 then
        return nil
    end
    local C_Map = _G.C_Map
    if C_Map and C_Map.GetAreaInfo then
        local name = C_Map.GetAreaInfo(areaId)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

--- Calls fn in protected mode, routing any error to the game's error handler instead of
--- propagating it. Used around code that runs inside another addon's call stack.
local function HandleResult(ok, ...)
    if not ok then
        geterrorhandler()((...))
        return false
    end
    return true, ...
end

---@param fn function
---@return boolean ok
---@return any ...
function Util.SafeCall(fn, ...)
    return HandleResult(pcall(fn, ...))
end
