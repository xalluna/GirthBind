-- Quest/QuestLog.lua
--
-- The player's own quest log, the lookup window's default list.

---@type string, GirthBindNamespace
local _, ns = ...

---@class GirthBindQuestLog
local QuestLog = {}
ns.QuestLog = QuestLog

---@class GirthBindQuestLogEntry
---@field kind "header"|"quest"
---@field id integer? Quest ID (quests only)
---@field name string Quest title or zone header
---@field level integer?
---@field isComplete boolean?

--- Quest log rows in log order, zone headers included. Hidden quests are skipped.
---@return GirthBindQuestLogEntry[]
function QuestLog.GetEntries()
    local entries = {}
    local api = _G.C_QuestLog
    if not (api and api.GetNumQuestLogEntries and api.GetInfo) then
        return entries
    end
    local pendingHeader
    for logIndex = 1, api.GetNumQuestLogEntries() do
        local info = api.GetInfo(logIndex)
        if info then
            if info.isHeader then
                pendingHeader = { kind = "header", name = info.title or "" }
            elseif not info.isHidden and info.questID and info.questID > 0 then
                if pendingHeader then
                    entries[#entries + 1] = pendingHeader
                    pendingHeader = nil
                end
                entries[#entries + 1] = {
                    kind = "quest",
                    id = info.questID,
                    name = info.title or "",
                    level = info.level,
                    isComplete = api.IsComplete and api.IsComplete(info.questID) or false,
                }
            end
        end
    end
    return entries
end

---@param questId integer
---@return boolean
function QuestLog.IsOnQuest(questId)
    local api = _G.C_QuestLog
    return api and api.IsOnQuest and api.IsOnQuest(questId) or false
end
