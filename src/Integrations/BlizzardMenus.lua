-- Integrations/BlizzardMenus.lua
--
-- Adds a "GirthBind" submenu to the client's own quest menus (the Menu API):
--   * MENU_QUEST_OBJECTIVE_TRACKER - the objective tracker's quest header menu
--   * MENU_QUEST_MAP_LOG_TITLE     - the quest log's quest title menu
--
-- The tracker menu's owner is the tracker, not the quest, so the quest is taken from the quest
-- header the cursor last entered (Blizzard fires OnQuestBlockHeader.OnEnter), provided the
-- cursor is still over it. The quest log's owner carries questID directly.

---@type string, GirthBindNamespace
local _, ns = ...
local Log, Util, MenuModel = ns.Log, ns.Util, ns.MenuModel

---@class GirthBindBlizzardMenus : AceModule
local BlizzardMenus = ns.addon:NewModule("BlizzardMenus")
ns.BlizzardMenus = BlizzardMenus

BlizzardMenus.TRACKER_TAG = "MENU_QUEST_OBJECTIVE_TRACKER"
BlizzardMenus.QUEST_LOG_TAG = "MENU_QUEST_MAP_LOG_TITLE"

local TITLE_COLOR = Util.COLORS.TAG

-- ModifyMenu also visits the last description it generated when a callback registers, so each
-- root description is decorated at most once.
local decorated = setmetatable({}, { __mode = "k" })
local hoveredBlock

---@param value any
---@return integer?
local function AsQuestId(value)
    if Util.IsSecret(value) or type(value) ~= "number" or value <= 0 or value % 1 ~= 0 then
        return nil
    end
    return value
end

--- Draws a menu model into a Menu API root description.
---@param root table Menu API element description
---@param model GirthBindMenu
function BlizzardMenus.Render(root, model)
    if decorated[root] then
        return
    end
    decorated[root] = true
    root:CreateDivider()
    local entry = root:CreateButton(Util.Color(TITLE_COLOR, model.title))
    if not model.enabled then
        entry:SetEnabled(false)
        if model.reason and entry.SetTooltip then
            entry:SetTooltip(function(tooltip)
                GameTooltip_SetTitle(tooltip, model.title)
                GameTooltip_AddNormalLine(tooltip, model.reason)
            end)
        end
        return
    end
    for _, item in ipairs(model.items) do
        entry:CreateButton(item.text, function()
            item.action()
        end)
    end
end

---@return integer?
function BlizzardMenus.GetHoveredTrackerQuest()
    local block = hoveredBlock
    local header = block and block.HeaderButton
    if not (header and header:IsMouseOver()) then
        return nil
    end
    return AsQuestId(block.id)
end

local function OnTrackerMenu(_, root)
    local questId = BlizzardMenus.GetHoveredTrackerQuest()
    if questId then
        BlizzardMenus.Render(root, MenuModel.Build(questId))
    end
end

local function OnQuestLogMenu(owner, root)
    local questId = AsQuestId(type(owner) == "table" and owner.questID or nil)
    if questId then
        BlizzardMenus.Render(root, MenuModel.Build(questId))
    end
end

function BlizzardMenus:OnEnable()
    local Menu = _G.Menu
    if not (Menu and Menu.ModifyMenu) then
        Log.Debug("Menu API unavailable; Blizzard quest menus not hooked")
        return
    end
    local function Guarded(callback)
        return function(...)
            Util.SafeCall(callback, ...)
        end
    end
    self.trackerHandle = Menu.ModifyMenu(BlizzardMenus.TRACKER_TAG, Guarded(OnTrackerMenu))
    self.questLogHandle = Menu.ModifyMenu(BlizzardMenus.QUEST_LOG_TAG, Guarded(OnQuestLogMenu))

    local registry = _G.EventRegistry
    if registry and registry.RegisterCallbackWithHandle then
        self.hoverHandle = registry:RegisterCallbackWithHandle("OnQuestBlockHeader.OnEnter", function(_, block)
            hoveredBlock = block
        end)
    end
    Log.Debug("Hooked Blizzard quest menus")
end
