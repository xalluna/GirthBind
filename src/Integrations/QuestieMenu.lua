-- Integrations/QuestieMenu.lua
--
-- Adds a "GirthBind" submenu to Questie's tracker right-click menu, just above Cancel.
--
-- Questie builds that menu in TrackerMenu:GetMenuForQuest(quest), an internal module rather than
-- part of Questie.API, so a Questie update could change it. The wrapper is defensive: Questie's
-- own menu always comes back, and if our part fails the entry is simply missing.

---@type string, GirthBindNamespace
local _, ns = ...
local Log, Util, MenuModel = ns.Log, ns.Util, ns.MenuModel

---@class GirthBindQuestieMenu : AceModule
local QuestieMenu = ns.addon:NewModule("QuestieMenu")
ns.QuestieMenu = QuestieMenu

local HOOK_FLAG = "__GirthBindHooked"
local TITLE_COLOR = Util.COLORS.TAG

--- Turns a menu model into LibUIDropDownMenu (EasyMenu) entries.
---@param model GirthBindMenu
---@return table entry
function QuestieMenu.BuildEntry(model)
    local entry = {
        text = Util.Color(TITLE_COLOR, model.title),
        notCheckable = true,
        hasArrow = model.enabled,
        disabled = not model.enabled,
    }
    if model.enabled then
        local subMenu = {}
        for _, item in ipairs(model.items) do
            subMenu[#subMenu + 1] = {
                text = item.text,
                notCheckable = true,
                func = item.action,
            }
        end
        entry.menuList = subMenu
    elseif model.reason then
        entry.tooltipTitle = model.title
        entry.tooltipText = model.reason
        entry.tooltipOnButton = true
        entry.tooltipWhileDisabled = true
    end
    return entry
end

--- Inserts the entry just above Questie's Cancel row (or at the end if there is none).
---@param menu table Questie's menu list
---@param entry table
function QuestieMenu.InsertEntry(menu, entry)
    local position = #menu + 1
    for index, item in ipairs(menu) do
        if type(item) == "table" and item.text == _G.CANCEL then
            position = index
            break
        end
    end
    table.insert(menu, position, entry)
end

local function Decorate(menu, quest)
    local questId = type(quest) == "table" and quest.Id
    if type(questId) ~= "number" then
        return
    end
    QuestieMenu.InsertEntry(menu, QuestieMenu.BuildEntry(MenuModel.Build(questId)))
end

---@return table? TrackerMenu Questie's internal tracker menu module
local function GetTrackerMenu()
    local loader = _G.QuestieLoader
    if not (loader and loader.ImportModule and C_AddOns.IsAddOnLoaded("Questie")) then
        return nil
    end
    local ok, trackerMenu = pcall(loader.ImportModule, loader, "TrackerMenu")
    if ok and type(trackerMenu) == "table" then
        return trackerMenu
    end
    return nil
end

function QuestieMenu:OnEnable()
    local trackerMenu = GetTrackerMenu()
    if not trackerMenu then
        Log.Debug("Questie isn't loaded; no tracker menu to hook")
        return
    end
    local original = trackerMenu.GetMenuForQuest
    if type(original) ~= "function" then
        Log.Warn("Questie's tracker menu changed shape; the GirthBind entry is unavailable")
        return
    end
    if trackerMenu[HOOK_FLAG] then
        return
    end
    trackerMenu[HOOK_FLAG] = true

    trackerMenu.GetMenuForQuest = function(menuModule, quest, ...)
        local menu = original(menuModule, quest, ...)
        if type(menu) == "table" then
            Util.SafeCall(Decorate, menu, quest)
        end
        return menu
    end
    Log.Debug("Hooked Questie's tracker menu")
end
