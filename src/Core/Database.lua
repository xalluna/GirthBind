-- Core/Database.lua
--
-- SavedVariables schema, defaults, and load-time repair. Settings are account-wide (AceDB's
-- `global` section). A value that fails validation falls back to its default rather than
-- breaking the addon.

---@type string, GirthBindNamespace
local _, ns = ...

---@class GirthBindDatabase
local Database = {}
ns.Database = Database

Database.SCHEMA_VERSION = 1

-- Same limit as the name box in /macro.
Database.MAX_MACRO_NAME = 16
Database.DEFAULT_MACRO_NAME = ns.RELEASE_NAME

---@class GirthBindBound
---@field name string Enemy name the macro targets
---@field npcId integer? NPC ID it came from, when known

---@class GirthBindGlobalSettings
---@field schemaVersion integer
---@field macro { name: string, body: string } body is the token template, not the rendered macro
---@field bound GirthBindBound? The one enemy the macro targets; nil = idle macro
---@field debugLevel GirthBindLogLevel
---@field window { point: string, relativePoint: string, x: number, y: number }

--- Built lazily because Template (which owns the default body) loads after this file.
---@return table
function Database.GetDefaults()
    return {
        global = {
            schemaVersion = Database.SCHEMA_VERSION,
            macro = {
                name = Database.DEFAULT_MACRO_NAME,
                body = ns.Template.DEFAULT_BODY,
            },
            debugLevel = ns.Log.DEFAULT_LEVEL,
            window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
        },
    }
end

---@param name any
---@return boolean
function Database.IsValidMacroName(name)
    if type(name) ~= "string" or name:match("^%s*$") then
        return false
    end
    return ns.Util.Utf8Len(name) <= Database.MAX_MACRO_NAME
end

---@param bound any
---@return boolean
function Database.IsValidBound(bound)
    return type(bound) == "table"
        and type(bound.name) == "string"
        and not bound.name:match("^%s*$")
        and (bound.npcId == nil or type(bound.npcId) == "number")
end

--- Repairs anything a hand-edited or older SavedVariables file got wrong.
---@param global GirthBindGlobalSettings
function Database.Sanitize(global)
    local defaults = Database.GetDefaults().global

    if type(global.macro) ~= "table" then
        global.macro = {}
    end
    if not Database.IsValidMacroName(global.macro.name) then
        global.macro.name = defaults.macro.name
    end
    if type(global.macro.body) ~= "string" then
        global.macro.body = defaults.macro.body
    end
    if global.bound ~= nil and not Database.IsValidBound(global.bound) then
        global.bound = nil
    end
    if not ns.Log.IsValidLevel(global.debugLevel) then
        global.debugLevel = defaults.debugLevel
    end
    local window = global.window
    if type(window) ~= "table" or type(window.point) ~= "string" or type(window.relativePoint) ~= "string"
        or type(window.x) ~= "number" or type(window.y) ~= "number" then
        global.window = defaults.window
    end
    global.schemaVersion = Database.SCHEMA_VERSION
end

--- Opens (or creates) the SavedVariables table and returns the AceDB object.
---@param svName string Global SavedVariables name from the TOC
---@return table db AceDB-3.0 database
function Database.Initialize(svName)
    local db = LibStub("AceDB-3.0"):New(svName, Database.GetDefaults(), true)
    Database.Sanitize(db.global)
    return db
end
