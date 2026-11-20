-- GirthBinder
-- Saves your target as a brief entity { EntityId, Name } and keeps one macro,
-- "GirthBinder", in sync with it:
--
--   /targetexact <Current.Name>
--   /cleartarget [dead]
--   /tm <mark>
--
-- Targeting and raid marks are protected actions (marks since Midnight 12.0),
-- so only a key press or click can do them: the macro does the work and the
-- slash commands configure it.
--
--   /girthbinder                        save target (old Current -> Previous)
--   /girthbinder target                 put the GirthBinder macro on your cursor
--   /girthbinder mark <markName>        choose the mark the macro applies
--   /girthbinder mark list              list mark names
--   /girthbinder rename <name>          rename the managed macro
--   /girthbinder debug log|info|warning|error|none

local ADDON_NAME = ...

local DEFAULT_MACRO_NAME = "GirthBinder"
local MAX_MACRO_NAME = 16 -- same limit as the name box in /macro
local MACRO_ICON = 134400 -- question mark; change it in /macro and GirthBinder keeps yours
local MAX_MACRO_BODY = 255
local IDLE_BODY = "/stopmacro" -- before anything is saved, pressing the macro does nothing
local DEFAULT_MARK = 8

-- Debug levels: a message prints when its level is at or above the chosen one.
local LEVELS = { log = 1, info = 2, warning = 3, error = 4, none = 5 }
local LEVEL_COLORS = {
    log     = "ff9d9d9d",
    info    = "ff66ccff",
    warning = "ffffcc00",
    error   = "ffff4040",
}

-- Raid target marks, keyed by the number /tm uses. 0 means "don't mark".
local MARKS = {
    [8] = { name = "Skull",    names = { "skull", "8" },             desc = 'white skull; usually "kill first"' },
    [7] = { name = "Cross",    names = { "cross", "x", "red", "7" }, desc = 'red X; usually "kill second"' },
    [6] = { name = "Square",   names = { "square", "blue", "6" },    desc = "blue square; often a hunter's trap target" },
    [5] = { name = "Moon",     names = { "moon", "silver", "5" },    desc = "silver moon; often a mage's polymorph target" },
    [4] = { name = "Triangle", names = { "triangle", "green", "4" }, desc = "green triangle" },
    [3] = { name = "Diamond",  names = { "diamond", "purple", "3" }, desc = "purple diamond" },
    [2] = { name = "Circle",   names = { "circle", "orange", "2" },  desc = "orange circle" },
    [1] = { name = "Star",     names = { "star", "yellow", "1" },    desc = "yellow star" },
    [0] = { name = "None",     names = { "none", "off" },            desc = "don't mark; the macro only targets" },
}
local MARK_ORDER = { 8, 7, 6, 5, 4, 3, 2, 1, 0 }
local MARK_BY_NAME = {}
for index, mark in pairs(MARKS) do
    for _, alias in ipairs(mark.names) do
        MARK_BY_NAME[alias] = index
    end
end

local TAG = "|cff33ff99[GirthBinder]|r"
local GRAY, GOLD, WHITE, GREEN = "|cff9d9d9d", "|cffffd100", "|cffffffff", "|cff00ff00"

local db -- GirthBinderDB, available after ADDON_LOADED
local events = CreateFrame("Frame")
local syncQueued = false

--------------------------------------------------------------------------------
-- Output
--------------------------------------------------------------------------------

local function Format(fmt, ...)
    if select("#", ...) > 0 then
        return fmt:format(...)
    end
    return fmt
end

local function Print(fmt, ...)
    print(TAG .. " " .. Format(fmt, ...))
end

-- [GirthBinder]  - <logLevel> - <message>
local function Log(level, fmt, ...)
    local threshold = (db and db.debugLevel) or "none"
    if LEVELS[level] < LEVELS[threshold] then
        return
    end
    print(("%s  - |c%s%s|r - %s"):format(TAG, LEVEL_COLORS[level], level, Format(fmt, ...)))
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- Midnight/Forever hand addons "secret values" for unit identity in combat and
-- in restricted content. Secret values can't be compared or tested, so check
-- before touching them.
local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) or false
end

-- Creatures use their NPC ID (stable across spawns); anything else uses its GUID.
-- Creature GUID: Creature-0-[server]-[instance]-[zone]-[npcId]-[spawn]
local function ParseEntityId(guid)
    local unitType, _, _, _, _, npcId = strsplit("-", guid)
    if (unitType == "Creature" or unitType == "Vehicle" or unitType == "Pet") and tonumber(npcId) then
        return tonumber(npcId)
    end
    return guid
end

local function DescribeEntity(entity)
    if not entity then
        return GRAY .. "none|r"
    end
    return ("%s%s|r %s(EntityId %s)|r"):format(WHITE, entity.Name, GRAY, tostring(entity.EntityId))
end

local function MarkLabel(index)
    local mark = MARKS[index]
    if index == 0 then
        return WHITE .. mark.name .. "|r"
    end
    return ("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0|t %s%s|r"):format(index, WHITE, mark.name)
end

--------------------------------------------------------------------------------
-- The GirthBinder macro
--------------------------------------------------------------------------------

local function BuildMacroBody()
    local current = db.Current
    if not current then
        return IDLE_BODY
    end
    local lines = {
        "/targetexact " .. current.Name,
        "/cleartarget [dead]",
    }
    if db.mark > 0 then
        lines[#lines + 1] = "/tm " .. db.mark
    end
    return table.concat(lines, "\n")
end

local function DescribeMacro()
    if not db.Current then
        return "does nothing yet (no target saved)"
    end
    if db.mark == 0 then
        return ("targets %s%s|r (no mark)"):format(WHITE, db.Current.Name)
    end
    return ("targets %s%s|r and marks it %s"):format(WHITE, db.Current.Name, MarkLabel(db.mark))
end

-- Writes the macro body. Returns "created", "updated", "unchanged", "queued",
-- "missing" (doesn't exist and allowCreate is false) or "error".
-- allowCreate is false at login: macros may not be loaded yet, and creating
-- then would make a duplicate.
local function SyncMacro(allowCreate)
    if InCombatLockdown() then
        syncQueued = true
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        Log("info", "In combat; macro update queued")
        return "queued"
    end
    syncQueued = false

    local body = BuildMacroBody()
    if #body > MAX_MACRO_BODY then
        Log("error", "Macro body is %d characters (limit %d)", #body, MAX_MACRO_BODY)
        Print("The macro would be %d characters (limit %d); it wasn't updated.", #body, MAX_MACRO_BODY)
        return "error"
    end

    local index = GetMacroIndexByName(db.macroName)
    if not index or index == 0 then
        if not allowCreate then
            Log("log", "Macro %s not found; not creating it during login", db.macroName)
            return "missing"
        end
        local numAccount = GetNumMacros()
        local maxAccount = MAX_ACCOUNT_MACROS or 120
        if numAccount >= maxAccount then
            Log("error", "Account macros full (%d/%d)", numAccount, maxAccount)
            Print("Your account macros are full (%d/%d). Delete one so GirthBinder can make its macro.",
                numAccount, maxAccount)
            return "error"
        end
        local ok, result = pcall(CreateMacro, db.macroName, MACRO_ICON, body, false)
        if not ok or not result then
            Log("error", "CreateMacro failed: %s", tostring(result))
            Print("Couldn't create the %s macro: %s", db.macroName, tostring(result))
            return "error"
        end
        Log("info", "Created macro %s (ID %s)", db.macroName, tostring(result))
        Log("log", "Macro body:\n%s", body)
        return "created"
    end

    local name, icon, oldBody = GetMacroInfo(index)
    if oldBody == body then
        Log("log", "Macro %s already up to date", db.macroName)
        return "unchanged"
    end
    local ok, err = pcall(EditMacro, index, name, icon, body)
    if not ok then
        Log("error", "EditMacro failed: %s", tostring(err))
        Print("Couldn't update the %s macro: %s", db.macroName, tostring(err))
        return "error"
    end
    Log("info", "Updated macro %s (ID %d)", db.macroName, index)
    Log("log", "Macro body:\n%s", body)
    return "updated"
end

-- One line telling the user what just happened to the macro.
local function ReportSync(result)
    if result == "created" then
        Print("Made a macro named %s%s|r that %s. Type %s/girthbinder target|r to put it on your cursor, then drop it on an action bar.",
            GOLD, db.macroName, DescribeMacro(), WHITE)
    elseif result == "updated" or result == "unchanged" then
        Print("%s%s|r macro %s.", GOLD, db.macroName, DescribeMacro())
    elseif result == "queued" then
        Print("You're in combat; the %s%s|r macro will update when combat ends.", GOLD, db.macroName)
    end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local function ShowSaved()
    Print("  Current:  %s", DescribeEntity(db.Current))
    Print("  Previous: %s", DescribeEntity(db.Previous))
end

local function CmdInspect()
    if not UnitExists("target") then
        Log("warning", "Inspect called with no target")
        Print("You don't have a target.")
        ShowSaved()
        return
    end

    local guid = UnitGUID("target")
    local name = UnitName("target")
    if IsSecret(guid) or IsSecret(name) then
        Log("warning", "Target identity is secret (combat or restricted content)")
        Print("Your target's identity is hidden right now (combat or restricted content). Try again out of combat.")
        return
    end
    if not guid or not name then
        Log("error", "UnitGUID/UnitName returned nil for an existing target (guid=%s, name=%s)", tostring(guid), tostring(name))
        Print("Couldn't read your target. Try again in a moment.")
        return
    end

    local entity = { EntityId = ParseEntityId(guid), Name = name }
    Log("log", "Target GUID %s -> EntityId %s", guid, tostring(entity.EntityId))

    local current = db.Current
    if current and current.EntityId == entity.EntityId and current.Name == entity.Name then
        Log("info", "Target matches Current; Previous left unchanged")
        Print("%s is already saved as Current.", DescribeEntity(entity))
    else
        db.Previous = current
        db.Current = entity
        Log("info", "Saved Current=%s, Previous=%s", entity.Name, current and current.Name or "nil")
        Print("Saved your target.")
    end
    ShowSaved()
    ReportSync(SyncMacro(true))
end

local function CmdTarget()
    Print("Addons can't target units; only a key press or click can. The %s%s|r macro does it for you.", GOLD, db.macroName)
    if InCombatLockdown() then
        Print("Leave combat, then type %s/girthbinder target|r again to pick the macro up.", WHITE)
        return
    end

    local result = SyncMacro(true)
    if result == "error" then
        return
    end
    local index = GetMacroIndexByName(db.macroName)
    local ok, err = pcall(PickupMacro, index)
    if not ok then
        Log("error", "PickupMacro failed: %s", tostring(err))
        Print("Couldn't pick it up (%s). Open %s/macro|r and drag %s%s|r onto a bar instead.",
            tostring(err), WHITE, GOLD, db.macroName)
        return
    end
    Print("It's on your cursor now; drop it on an action bar. It %s.", DescribeMacro())
end

local function CmdMarkList()
    Print("Marks for %s/girthbinder mark <name>|r:", WHITE)
    for _, index in ipairs(MARK_ORDER) do
        local mark = MARKS[index]
        Print("  %s %s- %s.|r Names: %s%s|r%s",
            MarkLabel(index), GRAY, mark.desc,
            GOLD, table.concat(mark.names, ", "),
            index == db.mark and (GREEN .. "  (current)|r") or "")
    end
end

local function CmdMark(arg)
    local key = arg:lower()
    if key == "" then
        Print("Current mark: %s. Type %s/girthbinder mark list|r to see the names.", MarkLabel(db.mark), WHITE)
        return
    end
    if key == "list" then
        CmdMarkList()
        return
    end

    local index = MARK_BY_NAME[key]
    if not index then
        Log("warning", "Unknown mark '%s'", arg)
        Print("Unknown mark %s%s|r. Type %s/girthbinder mark list|r to see the names.", WHITE, arg, WHITE)
        return
    end

    db.mark = index
    Log("info", "Mark set to %d (%s)", index, MARKS[index].name)
    Print("Mark set to %s.", MarkLabel(index))
    ReportSync(SyncMacro(true))
end

local function CmdRename(arg)
    local newName = (arg:match('^"(.*)"$') or arg:match("^'(.*)'$") or arg):match("^%s*(.-)%s*$")
    local oldName = db.macroName
    if newName == "" then
        Print("Usage: %s/girthbinder rename <name>|r (currently %s%s|r)", WHITE, GOLD, oldName)
        return
    end
    local length = strlenutf8 and strlenutf8(newName) or #newName
    if length > MAX_MACRO_NAME then
        Print("%s%s|r is %d characters; macro names can be at most %d.", WHITE, newName, length, MAX_MACRO_NAME)
        return
    end
    if newName == oldName then
        Print("The macro is already named %s%s|r.", GOLD, oldName)
        return
    end
    -- Renaming while in combat could leave the saved name pointing at nothing,
    -- and the queued update would then create a second macro.
    if InCombatLockdown() then
        Print("Macros can't be renamed in combat.")
        return
    end

    local index = GetMacroIndexByName(oldName)
    local clash = GetMacroIndexByName(newName)
    if clash and clash ~= 0 and clash ~= index then
        Log("warning", "Rename blocked: '%s' already exists (ID %d)", newName, clash)
        Print("You already have a macro named %s%s|r (ID %d). Pick another name or rename that one first.",
            GOLD, newName, clash)
        return
    end

    if not index or index == 0 then
        db.macroName = newName
        Log("info", "No macro to rename yet; saved name '%s' for when it's created", newName)
        Print("The macro will be named %s%s|r when it's created.", GOLD, newName)
        return
    end

    local _, icon, body = GetMacroInfo(index)
    local ok, err = pcall(EditMacro, index, newName, icon, body)
    if not ok then
        Log("error", "EditMacro rename failed: %s", tostring(err))
        Print("Couldn't rename %s%s|r: %s", GOLD, oldName, tostring(err))
        return
    end
    db.macroName = newName
    Log("info", "Renamed macro '%s' -> '%s'", oldName, newName)
    Print("Renamed the macro %s%s|r -> %s%s|r.", GOLD, oldName, GOLD, newName)
end

local function CmdDebug(arg)
    local level = arg:lower()
    if level == "" then
        Print("Debug level is %s%s|r. Options: log, info, warning, error, none", WHITE, db.debugLevel)
        return
    end
    if not LEVELS[level] then
        Print("Unknown debug level %s%s|r. Options: log, info, warning, error, none", WHITE, arg)
        return
    end
    db.debugLevel = level
    Print("Debug level set to %s%s|r.", WHITE, level)
end

local function PrintHelp()
    Print("Commands:")
    Print("  %s/girthbinder|r - save your target; the %s macro then targets it", WHITE, db.macroName)
    Print("  %s/girthbinder target|r - put the %s macro on your cursor", WHITE, db.macroName)
    Print("  %s/girthbinder mark <name>|r - choose the mark the macro applies", WHITE)
    Print("  %s/girthbinder mark list|r - list mark names", WHITE)
    Print("  %s/girthbinder rename <name>|r - rename the %s macro", WHITE, db.macroName)
    Print("  %s/girthbinder debug log||info||warning||error||none|r - set debug output", WHITE)
end

--------------------------------------------------------------------------------
-- Slash command
--------------------------------------------------------------------------------

SLASH_GIRTHBINDER1 = "/girthbinder"
SlashCmdList.GIRTHBINDER = function(msg)
    if not db then
        Print("Still loading; try again in a moment.")
        return
    end

    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    cmd = cmd:lower()
    Log("log", "Command '%s', args '%s'", cmd, rest)

    if cmd == "" then
        CmdInspect()
    elseif cmd == "target" then
        CmdTarget()
    elseif cmd == "mark" then
        CmdMark(rest)
    elseif cmd == "rename" then
        CmdRename(rest)
    elseif cmd == "debug" then
        CmdDebug(rest)
    elseif cmd == "help" or cmd == "?" then
        PrintHelp()
    else
        Print("Unknown command %s%s|r.", WHITE, cmd)
        PrintHelp()
    end
end

--------------------------------------------------------------------------------
-- Events and saved variables
--------------------------------------------------------------------------------

local function IsValidEntity(entity)
    return type(entity) == "table" and type(entity.Name) == "string" and entity.EntityId ~= nil
end

local function OnAddonLoaded()
    if type(GirthBinderDB) ~= "table" then
        GirthBinderDB = {}
    end
    db = GirthBinderDB
    if not IsValidEntity(db.Current) then db.Current = nil end
    if not IsValidEntity(db.Previous) then db.Previous = nil end
    if not LEVELS[db.debugLevel or ""] then db.debugLevel = "none" end
    if type(db.mark) ~= "number" or not MARKS[db.mark] then db.mark = DEFAULT_MARK end
    if type(db.macroName) ~= "string" or db.macroName:match("^%s*$") then db.macroName = DEFAULT_MACRO_NAME end

    Log("log", "Loaded. Current=%s, Previous=%s, mark=%d, macro=%s, debug=%s",
        db.Current and db.Current.Name or "nil",
        db.Previous and db.Previous.Name or "nil",
        db.mark, db.macroName, db.debugLevel)
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON_NAME then
            self:UnregisterEvent("ADDON_LOADED")
            OnAddonLoaded()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Catch up on anything that changed while the macro couldn't be written.
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        if db then
            SyncMacro(false)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if syncQueued then
            Log("info", "Combat ended; applying queued macro update")
            ReportSync(SyncMacro(true))
        end
    end
end)
