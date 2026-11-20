-- Integrations/EllesmereMenu.lua
--
-- Adds a "GirthBind" submenu to EllesmereUI's custom WoW Forever quest tracker.
--
-- EllesmereUI builds that menu in a local function and shows it through the public
-- EllesmereUI.ShowContextMenu(anchor, items, opts), so this wraps that function and acts only
-- when the anchor is one of the tracker's quest rows (kind "quest", numeric id) whose menu
-- starts with that quest's title. Every other EllesmereUI menu passes through untouched. This
-- depends on EllesmereUI internals and can silently stop matching after an EllesmereUI update.

---@type string, GirthBindNamespace
local _, ns = ...
local Log, Util, MenuModel = ns.Log, ns.Util, ns.MenuModel

---@class GirthBindEllesmereMenu : AceModule
local EllesmereMenu = ns.addon:NewModule("EllesmereMenu")
ns.EllesmereMenu = EllesmereMenu

local HOOK_FLAG = "__GirthBindShowContextMenu"
local TITLE_COLOR = Util.COLORS.TAG

--- The quest ID behind an EllesmereUI custom tracker quest menu, or nil for any other menu.
---@param anchor any
---@param items any
---@return integer?
function EllesmereMenu.GetQuestId(anchor, items)
    if type(anchor) ~= "table" or type(items) ~= "table" or anchor.kind ~= "quest" then
        return nil
    end
    local questId = anchor.id
    if Util.IsSecret(questId) or type(questId) ~= "number" or questId <= 0 then
        return nil
    end
    local first = items[1]
    local title = C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questId)
    if type(first) ~= "table" or not title or first.text ~= title then
        return nil
    end
    return questId
end

--- EllesmereUI context menu item for a menu model.
---@param model GirthBindMenu
---@return table
function EllesmereMenu.BuildItem(model)
    local item = { text = Util.Color(TITLE_COLOR, model.title), noLoc = true }
    if model.enabled then
        local children = {}
        for _, entry in ipairs(model.items) do
            children[#children + 1] = { text = entry.text, noLoc = true, onClick = entry.action }
        end
        item.children = children
    else
        item.isDisabled = function()
            return true
        end
        item.tooltip = model.reason
    end
    return item
end

--- A copy of `items` with the divider and GirthBind entry appended, or nil to leave it alone.
---@return table?
function EllesmereMenu.Decorate(anchor, items)
    local questId = EllesmereMenu.GetQuestId(anchor, items)
    if not questId then
        return nil
    end
    local copy = {}
    for index, item in ipairs(items) do
        copy[index] = item
    end
    copy[#copy + 1] = "---"
    copy[#copy + 1] = EllesmereMenu.BuildItem(MenuModel.Build(questId))
    return copy
end

function EllesmereMenu:OnEnable()
    local ellesmere = _G.EllesmereUI
    if type(ellesmere) ~= "table" or type(ellesmere.ShowContextMenu) ~= "function" then
        Log.Debug("EllesmereUI isn't loaded; custom tracker menu not hooked")
        return
    end
    if ellesmere[HOOK_FLAG] then
        return
    end
    local original = ellesmere.ShowContextMenu
    ellesmere[HOOK_FLAG] = original
    ellesmere.ShowContextMenu = function(anchor, items, ...)
        local ok, decorated = Util.SafeCall(EllesmereMenu.Decorate, anchor, items)
        return original(anchor, (ok and decorated) or items, ...)
    end
    Log.Debug("Hooked EllesmereUI context menus")
end
