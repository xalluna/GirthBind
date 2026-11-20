-- locales/enUS.lua
--
-- Default (and fallback) strings. Other locales add a file like this one with
-- NewLocale(ADDON_NAME, "<locale>") and only the keys they translate; anything missing falls
-- back to these. Keys are stable identifiers; values may contain string.format placeholders,
-- noted where the arguments aren't obvious.

local ADDON_NAME = ...
local L = LibStub("AceLocale-3.0"):NewLocale(ADDON_NAME, "enUS", true)
if not L then
    return
end

-- Lifecycle
L["YIELD_TO_RELEASE"] = "%s (the release build) is installed and enabled, so this dev copy is turned off. Disable one of them."

-- QuestieDB
L["QUESTIEDB_MISSING"] = "Quest lookup needs the QuestieDB addon, which isn't installed or enabled."
L["QUESTIEDB_INCOMPATIBLE"] = "Quest lookup is off because QuestieDB is the wrong version. %s"

-- Macro
L["MACRO_DESCRIBE_TARGETS"] = "targets %s" -- enemy name
L["MACRO_DESCRIBE_IDLE"] = "does nothing yet (nothing is bound)"
L["MACRO_CREATED"] = "Made a macro named %s that %s. Type %s to put it on your cursor, then drop it on an action bar." -- macro, description, command
L["MACRO_UPDATED"] = "%s macro %s." -- macro, description
L["MACRO_QUEUED"] = "You're in combat; the %s macro will update when combat ends."
L["MACRO_TOO_LONG"] = "The macro would be %d characters (limit %d), so it wasn't updated. Shorten the macro body in /gb options."
L["MACRO_ACCOUNT_FULL"] = "Your account macros are full (%d/%d). Delete one so GirthBind can make its macro."
L["MACRO_CREATE_FAILED"] = "Couldn't create the %s macro: %s"
L["MACRO_EDIT_FAILED"] = "Couldn't update the %s macro: %s"
L["MACRO_UNKNOWN_ERROR"] = "Couldn't update the macro."

-- Binding
L["BIND_NO_TARGET"] = "You don't have a target. Target an enemy, then type /gb bind."
L["BIND_TARGET_SECRET"] = "Your target's identity is hidden right now (combat or restricted content). Try again out of combat."
L["BIND_TARGET_UNREADABLE"] = "Couldn't read your target. Try again in a moment."
L["BIND_TOO_LONG"] = "Binding %s would make the macro %d characters (limit %d), so nothing changed. Shorten the macro body in /gb options." -- name, length, limit
L["BOUND_CLEARED"] = "Cleared %s; the macro does nothing until you bind an enemy."

-- Template
L["TEMPLATE_INVALID"] = "The macro body must be text."
L["TEMPLATE_TOO_LONG"] = "That body makes a %d-character macro (limit %d). Shorten it."
L["TOKEN_TARGET_NAME"] = "the bound enemy's name"
L["TOKEN_TARGET_NAME_SAMPLE"] = "Kobold Vermin"

-- Rename
L["RENAME_EMPTY"] = "The macro needs a name."
L["RENAME_TOO_LONG"] = "%s is %d characters; macro names can be at most %d." -- name, length, limit
L["RENAME_COMBAT"] = "Macros can't be renamed in combat."
L["RENAME_ADOPTED"] = "GirthBind now manages your existing %s macro and has rewritten its body."
L["RENAME_ADOPTED_OLD_KEPT"] = "GirthBind now manages your existing %s macro and has rewritten its body. %s is left as it was and no longer updates." -- adopted, previous
L["RENAME_PENDING"] = "The macro will be named %s when it's created."
L["RENAME_DONE"] = "Renamed the macro %s -> %s." -- old, new
L["RENAME_FAILED"] = "Couldn't rename %s: %s"

-- Pickup
L["PICKUP_COMBAT"] = "Leave combat, then type %s again to pick the macro up."
L["PICKUP_DONE"] = "The %s macro is on your cursor; drop it on an action bar. It %s." -- macro, description
L["PICKUP_FAILED"] = "Couldn't pick it up (%s). Open %s and drag %s onto a bar instead." -- error, /macro, macro

-- Slash commands
L["CMD_LOADING"] = "Still loading; try again in a moment."
L["CMD_UNKNOWN"] = "Unknown command %s."
L["CMD_IDLOOKUP_USAGE"] = "Usage: %s"
L["CMD_IDLOOKUP_UNKNOWN"] = "QuestieDB has no quest with ID %d."
L["CMD_DEBUG_CURRENT"] = "Debug level is %s. Options: %s"
L["CMD_DEBUG_UNKNOWN"] = "Unknown debug level %s. Options: %s"
L["CMD_DEBUG_SET"] = "Debug level set to %s."
L["CMD_HELP_HEADER"] = "Commands:"
L["CMD_HELP_OPEN"] = "open the quest lookup window"
L["CMD_HELP_LOOKUP"] = "find a quest by name and list its enemies"
L["CMD_HELP_IDLOOKUP"] = "open a quest by its ID"
L["CMD_HELP_BIND"] = "bind your current target to the macro"
L["CMD_HELP_PICKUP"] = "put the %s macro on your cursor"
L["CMD_HELP_OPTIONS"] = "open the GirthBind options"
L["CMD_HELP_DEBUG"] = "set debug output"
L["CMD_HELP_HELP"] = "show this list"

-- Log levels
L["LOG_LEVEL_LOG"] = "Log (everything)"
L["LOG_LEVEL_INFO"] = "Info"
L["LOG_LEVEL_WARNING"] = "Warning"
L["LOG_LEVEL_ERROR"] = "Error"
L["LOG_LEVEL_NONE"] = "None"

-- Options page
L["OPTIONS_INTRO"] = "GirthBind keeps one macro that targets the enemy you bind. Bind enemies from the quest lookup (/gb), from a quest's right-click menu, or bind your current target with /gb bind."
L["OPTIONS_MACRO_HEADER"] = "Macro"
L["OPTIONS_MACRO_NAME"] = "Macro name"
L["OPTIONS_MACRO_NAME_DESC"] = "Name of the macro GirthBind manages (up to %d characters). Renaming keeps it on your action bars. Naming a macro you already have makes GirthBind manage that one instead, overwriting its body."
L["OPTIONS_PICKUP"] = "Pick up macro"
L["OPTIONS_PICKUP_DESC"] = "Put the macro on your cursor to drop on an action bar (/gb pickup)."
L["OPTIONS_BODY"] = "Macro body"
L["OPTIONS_BODY_DESC"] = "The macro text. Tokens like $Target.Name$ are replaced with the bound enemy."
L["OPTIONS_UNKNOWN_TOKENS"] = "Unknown tokens, left as typed: %s"
L["OPTIONS_RESET_BODY"] = "Reset body"
L["OPTIONS_RESET_BODY_DESC"] = "Restore the default macro body."
L["OPTIONS_RESET_BODY_CONFIRM"] = "Replace the macro body with the default?"
L["OPTIONS_TOKENS_INTRO"] = "Tokens:"
L["OPTIONS_TOKENS_ESCAPE"] = "  %s  a literal dollar sign"
L["OPTIONS_PREVIEW_BOUND"] = "Preview:"
L["OPTIONS_PREVIEW_SAMPLE"] = "Preview (sample values; nothing is bound yet):"
L["OPTIONS_PREVIEW_COUNT"] = "%d / %d characters"
L["OPTIONS_BOUND_HEADER"] = "Bound enemy"
L["OPTIONS_BOUND"] = "Bound: %s"
L["OPTIONS_BOUND_NPC"] = "Bound: %s (NPC %d)"
L["OPTIONS_BOUND_NONE"] = "Nothing is bound; the macro does nothing."
L["OPTIONS_CLEAR"] = "Clear"
L["OPTIONS_CLEAR_DESC"] = "Forget the bound enemy; the macro goes back to doing nothing."
L["OPTIONS_GENERAL_HEADER"] = "General"
L["OPTIONS_DEBUG"] = "Debug output"
L["OPTIONS_DEBUG_DESC"] = "How much diagnostic output to print in chat (/gb debug)."
L["OPTIONS_COMBAT"] = "Options can't be opened in combat."

-- Lookup window
L["WINDOW_TITLE"] = "GirthBind"
L["WINDOW_HINT"] = "Find a quest, then bind one of its enemies to your macro."
L["WINDOW_STATUS_LOG"] = "Your quest log (%d)"
L["WINDOW_STATUS_LOG_EMPTY"] = "Your quest log is empty. Search for any quest above."
L["WINDOW_STATUS_INDEXING"] = "Indexing quests... %d%%"
L["WINDOW_STATUS_MATCHES"] = "%d matching quests"
L["WINDOW_STATUS_NO_MATCHES"] = "No quests match."
L["WINDOW_STATUS_TRUNCATED"] = "Showing the first %d of %d matches"
L["WINDOW_PICK_QUEST"] = "Pick a quest to see its enemies."
L["WINDOW_QUEST_UNKNOWN"] = "QuestieDB has no quest with ID %d."
L["WINDOW_QUEST_UNKNOWN_TITLE"] = "Unknown quest"
L["WINDOW_NO_ENEMIES"] = "This quest has no enemies to bind."
L["WINDOW_GROUP_NO_ENEMIES"] = "No enemies give this; it comes from objects or elsewhere."
L["WINDOW_GROUP_COUNT"] = "%s x%d" -- objective, count
L["WINDOW_SHOW_MORE"] = "Show %d more..."
L["WINDOW_BIND_BUTTON"] = "Bind"
L["WINDOW_BOUND_BUTTON"] = "Bound"
L["WINDOW_LEVEL"] = "Level %s"
L["WINDOW_QUEST_LEVEL_REQ"] = "Level %d (requires %d)"
L["WINDOW_QUEST_ID"] = "Quest %d"
L["WINDOW_IN_LOG"] = "In your quest log"
L["WINDOW_COMPLETE_SUFFIX"] = "(Complete)"
L["WINDOW_TOOLTIP_NPC_IDS"] = "NPC IDs: %s"
L["WINDOW_TOOLTIP_IN_ZONE"] = "Found in the quest's zone"
L["WINDOW_FOOTER_BOUND"] = "The %s macro targets %s." -- macro, enemy
L["WINDOW_FOOTER_IDLE"] = "The %s macro does nothing yet. Bind an enemy below."

L["OBJECTIVE_KIND_KILL"] = "Kill"
L["OBJECTIVE_KIND_KILL_CREDIT"] = "Kill credit"
L["OBJECTIVE_KIND_ITEM"] = "Dropped by"
L["OBJECTIVE_KIND_SPECIAL"] = "Special objective"
L["OBJECTIVE_UNNAMED"] = "Objective"

L["RANK_ELITE"] = "Elite"
L["RANK_RARE_ELITE"] = "Rare elite"
L["RANK_BOSS"] = "Boss"
L["RANK_RARE"] = "Rare"

-- Quest menus
L["MENU_TITLE"] = "GirthBind"
L["MENU_OPEN"] = "Open in GirthBind..."
L["MENU_BOUND_FORMAT"] = "%s (bound)"
L["MENU_MORE"] = "%d more in the GirthBind window..."
L["MENU_REASON_UNKNOWN_QUEST"] = "QuestieDB doesn't know this quest."
L["MENU_REASON_NO_ENEMIES"] = "This quest has no enemies to bind."
