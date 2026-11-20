-- Integrations/MenuModel.lua
--
-- What the "GirthBind" entry in a quest's right-click menu contains, independent of which menu
-- system draws it. Each integration (Questie, Blizzard, EllesmereUI) renders this model.

---@type string, GirthBindNamespace
local _, ns = ...
local L, QuestData = ns.L, ns.QuestData

---@class GirthBindMenuModel
local MenuModel = {}
ns.MenuModel = MenuModel

MenuModel.MAX_ENEMIES = 15

---@class GirthBindMenuItem
---@field kind "open"|"bind"|"more"
---@field text string
---@field isBound boolean?
---@field enemy GirthBindEnemy?
---@field action fun()

---@class GirthBindMenu
---@field title string
---@field questId integer
---@field enabled boolean False: draw the entry greyed out, with `reason` as its tooltip
---@field reason string?
---@field items GirthBindMenuItem[] "Open in GirthBind…", then one Bind item per enemy

---@param questId integer
local function OpenWindow(questId)
    ns.Lookup:Open({ questId = questId })
end

--- The GirthBind entry for a quest.
---@param questId integer?
---@return GirthBindMenu
function MenuModel.Build(questId)
    local model = { title = L["MENU_TITLE"], questId = questId, enabled = false, items = {} }

    local status, message = QuestData.GetStatus()
    if status ~= QuestData.STATUS.OK then
        model.reason = message
        return model
    end
    if type(questId) ~= "number" or not QuestData.GetQuest(questId) then
        model.reason = L["MENU_REASON_UNKNOWN_QUEST"]
        return model
    end
    local enemies = QuestData.GetEnemies(questId)
    if #enemies == 0 then
        model.reason = L["MENU_REASON_NO_ENEMIES"]
        return model
    end

    model.enabled = true
    local items = model.items
    items[1] = {
        kind = "open",
        text = L["MENU_OPEN"],
        action = function()
            OpenWindow(questId)
        end,
    }

    local bound = ns.Macro:GetBound()
    for position = 1, math.min(#enemies, MenuModel.MAX_ENEMIES) do
        local enemy = enemies[position]
        local isBound = bound ~= nil and bound.name == enemy.name
        items[#items + 1] = {
            kind = "bind",
            text = isBound and L["MENU_BOUND_FORMAT"]:format(enemy.name) or enemy.name,
            isBound = isBound,
            enemy = enemy,
            action = function()
                ns.Macro:Bind({ name = enemy.name, npcId = enemy.npcId })
            end,
        }
    end
    if #enemies > MenuModel.MAX_ENEMIES then
        items[#items + 1] = {
            kind = "more",
            text = L["MENU_MORE"]:format(#enemies - MenuModel.MAX_ENEMIES),
            action = function()
                OpenWindow(questId)
            end,
        }
    end
    return model
end
