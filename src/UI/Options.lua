-- UI/Options.lua
--
-- The GirthBind page in Esc > Options > AddOns, built with AceConfig. Every setter goes through
-- the Macro module, so the page and the slash commands share one set of rules.

---@type string, GirthBindNamespace
local ADDON_NAME, ns = ...
local L, Log, Util, Template = ns.L, ns.Log, ns.Util, ns.Template
local MESSAGES = ns.MESSAGES

---@class GirthBindOptions : AceModule, AceEvent-3.0
local Options = ns.addon:NewModule("Options", "AceEvent-3.0")
ns.Options = Options

Options.APP_NAME = ADDON_NAME

local WHITE, GRAY, GOLD = Util.COLORS.WHITE, Util.COLORS.GRAY, Util.COLORS.GOLD

local function Macro()
    return ns.Macro
end

-- AceConfig validators return true to accept, or a message to show.
local function Accept(err)
    return err or true
end

--- The rendered body for the preview: with the bound enemy, else with sample values.
---@return string body
---@return boolean isSample
function Options.RenderPreview()
    local macro = Macro()
    local bound = macro:GetBound()
    if bound then
        return (macro:RenderFor(bound, macro:GetTemplate())), false
    end
    return (Template.Render(macro:GetTemplate(), nil, true)), true
end

---@return string
function Options.DescribeTokens()
    local lines = { L["OPTIONS_TOKENS_INTRO"] }
    for _, token in ipairs(Template.GetTokens()) do
        lines[#lines + 1] = ("  %s  %s"):format(Util.Color(GOLD, "$" .. token.key .. "$"), token.description)
    end
    lines[#lines + 1] = L["OPTIONS_TOKENS_ESCAPE"]:format(Util.Color(GOLD, "$$"))
    return table.concat(lines, "\n")
end

---@return string
function Options.DescribePreview()
    local body, isSample = Options.RenderPreview()
    local length = #body
    local limit = ns.Macro.MAX_BODY
    local count = L["OPTIONS_PREVIEW_COUNT"]:format(length, limit)
    if length > limit then
        count = Util.Color(Util.COLORS.RED, count)
    end
    local heading = isSample and L["OPTIONS_PREVIEW_SAMPLE"] or L["OPTIONS_PREVIEW_BOUND"]
    return ("%s\n%s\n%s"):format(heading, Util.Color(WHITE, body), Util.Color(GRAY, count))
end

---@return string?
function Options.DescribeUnknownTokens()
    local unknown = Template.FindUnknown(Macro():GetTemplate())
    if #unknown == 0 then
        return nil
    end
    return Util.Color("ffffcc00", L["OPTIONS_UNKNOWN_TOKENS"]:format(table.concat(unknown, ", ")))
end

---@return string
function Options.DescribeBound()
    local bound = Macro():GetBound()
    if not bound then
        return L["OPTIONS_BOUND_NONE"]
    end
    if bound.npcId then
        return L["OPTIONS_BOUND_NPC"]:format(Util.Color(WHITE, bound.name), bound.npcId)
    end
    return L["OPTIONS_BOUND"]:format(Util.Color(WHITE, bound.name))
end

--- The AceConfig options table.
---@return table
function Options.BuildTable()
    local levelValues, levelSorting = {}, {}
    for _, level in ipairs(Log.LEVEL_ORDER) do
        levelValues[level] = L["LOG_LEVEL_" .. level:upper()]
        levelSorting[#levelSorting + 1] = level
    end

    return {
        type = "group",
        name = ADDON_NAME,
        args = {
            intro = {
                order = 1,
                type = "description",
                name = L["OPTIONS_INTRO"],
                fontSize = "medium",
            },
            macroHeader = { order = 10, type = "header", name = L["OPTIONS_MACRO_HEADER"] },
            macroName = {
                order = 11,
                type = "input",
                name = L["OPTIONS_MACRO_NAME"],
                desc = L["OPTIONS_MACRO_NAME_DESC"]:format(ns.Database.MAX_MACRO_NAME),
                get = function()
                    return Macro():GetName()
                end,
                validate = function(_, value)
                    return Accept(Macro():ValidateName(value))
                end,
                set = function(_, value)
                    Macro():Rename(value)
                end,
            },
            pickup = {
                order = 12,
                type = "execute",
                name = L["OPTIONS_PICKUP"],
                desc = L["OPTIONS_PICKUP_DESC"],
                func = function()
                    Macro():Pickup()
                end,
            },
            body = {
                order = 13,
                type = "input",
                multiline = 6,
                width = "full",
                name = L["OPTIONS_BODY"],
                desc = L["OPTIONS_BODY_DESC"],
                get = function()
                    return Macro():GetTemplate()
                end,
                validate = function(_, value)
                    return Accept(Macro():ValidateTemplate(value))
                end,
                set = function(_, value)
                    Macro():SetTemplate(value)
                end,
            },
            unknownTokens = {
                order = 14,
                type = "description",
                name = function()
                    return Options.DescribeUnknownTokens() or ""
                end,
                hidden = function()
                    return Options.DescribeUnknownTokens() == nil
                end,
            },
            resetBody = {
                order = 15,
                type = "execute",
                name = L["OPTIONS_RESET_BODY"],
                desc = L["OPTIONS_RESET_BODY_DESC"],
                confirm = true,
                confirmText = L["OPTIONS_RESET_BODY_CONFIRM"],
                func = function()
                    Macro():ResetTemplate()
                end,
            },
            tokens = {
                order = 16,
                type = "description",
                name = Options.DescribeTokens,
            },
            preview = {
                order = 17,
                type = "description",
                name = Options.DescribePreview,
                fontSize = "medium",
            },
            boundHeader = { order = 20, type = "header", name = L["OPTIONS_BOUND_HEADER"] },
            bound = {
                order = 21,
                type = "description",
                name = Options.DescribeBound,
                fontSize = "medium",
                width = "double",
            },
            clear = {
                order = 22,
                type = "execute",
                name = L["OPTIONS_CLEAR"],
                desc = L["OPTIONS_CLEAR_DESC"],
                disabled = function()
                    return Macro():GetBound() == nil
                end,
                func = function()
                    Macro():Clear()
                end,
            },
            generalHeader = { order = 30, type = "header", name = L["OPTIONS_GENERAL_HEADER"] },
            debugLevel = {
                order = 31,
                type = "select",
                name = L["OPTIONS_DEBUG"],
                desc = L["OPTIONS_DEBUG_DESC"],
                values = levelValues,
                sorting = levelSorting,
                get = function()
                    return Log.GetLevel()
                end,
                set = function(_, value)
                    ns.db.global.debugLevel = value
                end,
            },
        },
    }
end

function Options:OnEnable()
    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    AceConfig:RegisterOptionsTable(Options.APP_NAME, Options.BuildTable)
    self.panel, self.categoryId = AceConfigDialog:AddToBlizOptions(Options.APP_NAME, ADDON_NAME)
    -- Visiting the page makes the (idle) macro, so it can go on a bar before anything is bound.
    if self.panel and self.panel.HookScript then
        self.panel:HookScript("OnShow", function()
            ns.Macro:EnsureExists()
        end)
    end
    self:RegisterMessage(MESSAGES.BOUND_CHANGED, "Refresh")
    self:RegisterMessage(MESSAGES.MACRO_CHANGED, "Refresh")
end

function Options:Refresh()
    LibStub("AceConfigRegistry-3.0"):NotifyChange(Options.APP_NAME)
end

--- Opens Esc > Options > AddOns > GirthBind (/gb options).
---@return boolean ok
function Options:Open()
    if InCombatLockdown() then
        Log.Print(L["OPTIONS_COMBAT"])
        return false
    end
    if not (self.categoryId and Settings and Settings.OpenToCategory) then
        Log.Error("Options category isn't registered")
        return false
    end
    Settings.OpenToCategory(self.categoryId)
    return true
end
