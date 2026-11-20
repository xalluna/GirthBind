-- Commands.lua
--
--   /gb                      open the lookup window (your quest log)
--   /gb lookup [questName]   open the window; with a name, search for it (one exact match opens it)
--   /gb idlookup <questId>   open the window on a quest by ID
--   /gb bind                 bind your current target
--   /gb pickup               put the managed macro on your cursor
--   /gb options              open Esc > Options > AddOns > GirthBind
--   /gb debug [level]        show or set debug output (log, info, warning, error, none)
--   /gb help                 list commands

---@type string, GirthBindNamespace
local _, ns = ...
local L, Log, Util, QuestData = ns.L, ns.Log, ns.Util, ns.QuestData

---@class GirthBindCommands : AceModule, AceConsole-3.0
local Commands = ns.addon:NewModule("Commands", "AceConsole-3.0")
ns.Commands = Commands

Commands.SLASH = "gb"

local WHITE = Util.COLORS.WHITE

--- Splits "lookup  The Defias Brotherhood " into "lookup", "The Defias Brotherhood".
---@param input string?
---@return string command Lowercased
---@return string rest Trimmed, case preserved
function Commands.Parse(input)
    local command, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    return (command or ""):lower(), rest or ""
end

local function Usage(command)
    return Util.Color(WHITE, "/" .. Commands.SLASH .. (command ~= "" and (" " .. command) or ""))
end

---@type table<string, fun(rest: string)>
local handlers = {}

handlers[""] = function()
    ns.Lookup:Open()
end

handlers.lookup = function(rest)
    local name = Util.Unquote(rest)
    if name == "" then
        ns.Lookup:Open()
        return
    end
    local status, message = QuestData.GetStatus()
    if status ~= QuestData.STATUS.OK then
        Log.Print(message)
    end
    ns.Lookup:Open({ query = name, exact = true })
end

handlers.idlookup = function(rest)
    local questId = tonumber(Util.Trim(rest):match("^#?(%d+)$") or "")
    if not questId then
        Log.Print(L["CMD_IDLOOKUP_USAGE"], Usage("idlookup <questId>"))
        return
    end
    local status, message = QuestData.GetStatus()
    if status ~= QuestData.STATUS.OK then
        Log.Print(message)
        return
    end
    if not QuestData.GetQuest(questId) then
        Log.Print(L["CMD_IDLOOKUP_UNKNOWN"], questId)
        return
    end
    ns.Lookup:Open({ questId = questId })
end

handlers.bind = function()
    ns.Macro:BindTarget()
end

handlers.pickup = function()
    ns.Macro:Pickup()
end

handlers.options = function()
    ns.Options:Open()
end
handlers.config = handlers.options

handlers.debug = function(rest)
    local level = Util.Trim(rest):lower()
    if level == "" then
        Log.Print(L["CMD_DEBUG_CURRENT"], Util.Color(WHITE, Log.GetLevel()), table.concat(Log.LEVEL_ORDER, ", "))
        return
    end
    if not Log.IsValidLevel(level) then
        Log.Print(L["CMD_DEBUG_UNKNOWN"], Util.Color(WHITE, rest), table.concat(Log.LEVEL_ORDER, ", "))
        return
    end
    ns.db.global.debugLevel = level
    Log.Print(L["CMD_DEBUG_SET"], Util.Color(WHITE, level))
end

function Commands.PrintHelp()
    Log.Print(L["CMD_HELP_HEADER"])
    Log.Print("  %s - %s", Usage(""), L["CMD_HELP_OPEN"])
    Log.Print("  %s - %s", Usage("lookup [questName]"), L["CMD_HELP_LOOKUP"])
    Log.Print("  %s - %s", Usage("idlookup <questId>"), L["CMD_HELP_IDLOOKUP"])
    Log.Print("  %s - %s", Usage("bind"), L["CMD_HELP_BIND"])
    Log.Print("  %s - %s", Usage("pickup"), L["CMD_HELP_PICKUP"]:format(ns.Macro:GetName()))
    Log.Print("  %s - %s", Usage("options"), L["CMD_HELP_OPTIONS"])
    Log.Print("  %s - %s", Usage("debug log||info||warning||error||none"), L["CMD_HELP_DEBUG"])
    Log.Print("  %s - %s", Usage("help"), L["CMD_HELP_HELP"])
end

handlers.help = Commands.PrintHelp
handlers["?"] = Commands.PrintHelp

--- Runs one /gb command line.
---@param input string?
function Commands:Handle(input)
    if not ns.db then
        Log.Print(L["CMD_LOADING"])
        return
    end
    local command, rest = Commands.Parse(input)
    Log.Debug("Command '%s', args '%s'", command, rest)
    local handler = handlers[command]
    if handler then
        handler(rest)
    else
        Log.Print(L["CMD_UNKNOWN"], Util.Color(WHITE, command))
        Commands.PrintHelp()
    end
end

function Commands:OnEnable()
    self:RegisterChatCommand(Commands.SLASH, "Handle")
end
