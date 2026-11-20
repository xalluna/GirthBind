-- Quest/QuestData.lua
--
-- The only file that reads QuestieDB (the LibQuestieDB global, public contract 4). Everything
-- else asks this module, so a QuestieDB API change lands in one place.
--
-- QuestieDB is optional. When it's missing or speaks another contract, GetStatus says why and
-- every read returns nil/empty.
--
-- Objective tuples (QuestieDB Types/General.t.lua):
--   objectives[1]  creature kills  { npcId, text?, count }
--   objectives[3]  items           { itemId, text?, count }   -> Item.npcDrops(itemId)
--   objectives[5]  kill credit     { npcIds[], rootNpcId, text?, count }
--   extraObjectives                { spawns?, icon, text?, index, refs[]? }, refs = { "monster", npcId }
-- Objects (objectives[2]) are left out: /targetexact can't target a game object.

---@type string, GirthBindNamespace
local _, ns = ...
local L, Util = ns.L, ns.Util

---@class GirthBindQuestData
local QuestData = {}
ns.QuestData = QuestData

QuestData.CONTRACT = 4

---@enum GirthBindQuestDataStatus
QuestData.STATUS = {
    OK = "ok",
    MISSING = "missing",
    INCOMPATIBLE = "incompatible",
}
local STATUS = QuestData.STATUS

---@alias GirthBindObjectiveKind "kill"|"killCredit"|"item"|"special"

---@class GirthBindEnemy
---@field name string Name the macro targets
---@field npcId integer First NPC ID with this name (lowest)
---@field npcIds integer[] Every NPC ID sharing this name, ascending
---@field minLevel integer?
---@field maxLevel integer?
---@field rank integer? QuestieDB rank: 1 elite, 2 rare elite, 3 boss, 4 rare
---@field zoneId integer? Most common AreaID
---@field inQuestZone boolean Lives in the quest's own zone

---@class GirthBindEnemyGroup
---@field kind GirthBindObjectiveKind
---@field label string Objective label (creature, item, or objective text)
---@field count integer? How many the objective needs
---@field enemies GirthBindEnemy[] Sorted: quest zone first, then level, then name

---@class GirthBindQuestInfo
---@field id integer
---@field name string
---@field level integer?
---@field requiredLevel integer?
---@field zoneId integer? Positive AreaID when the quest belongs to a zone
---@field zoneName string?

--- Read access to QuestieDB; replaceable in tests.
---@return table?
function QuestData.GetLibrary()
    return _G.LibQuestieDB
end

local cache = {}

--- Drops cached quest reads (e.g. after QuestieDB corrections change).
function QuestData.ClearCache()
    cache = {}
end

--- Whether QuestieDB can be used, and a user-facing reason when it can't.
---@return GirthBindQuestDataStatus status
---@return string? message
function QuestData.GetStatus()
    local db = QuestData.GetLibrary()
    if type(db) ~= "table" or type(db.RequireContract) ~= "function" then
        return STATUS.MISSING, L["QUESTIEDB_MISSING"]
    end
    local ok, reason = db.RequireContract(QuestData.CONTRACT)
    if not ok then
        return STATUS.INCOMPATIBLE, L["QUESTIEDB_INCOMPATIBLE"]:format(tostring(reason))
    end
    return STATUS.OK
end

---@return boolean
function QuestData.IsAvailable()
    return (QuestData.GetStatus()) == STATUS.OK
end

---@return table? db LibQuestieDB, only when the contract matches
local function DB()
    if QuestData.IsAvailable() then
        return QuestData.GetLibrary()
    end
    return nil
end

--- Every quest ID QuestieDB knows, ascending.
---@return integer[]
function QuestData.GetAllQuestIds()
    local db = DB()
    if not db then
        return {}
    end
    return db.Quest.GetAllIds() or {}
end

---@param questId integer
---@return string?
function QuestData.GetQuestName(questId)
    local db = DB()
    return db and db.Quest.name(questId) or nil
end

---@param questId integer
---@return GirthBindQuestInfo?
function QuestData.GetQuest(questId)
    local db = DB()
    if not db or type(questId) ~= "number" then
        return nil
    end
    local name = db.Quest.name(questId)
    if not name then
        return nil
    end
    local zoneOrSort = db.Quest.zoneOrSort(questId)
    local zoneId = (type(zoneOrSort) == "number" and zoneOrSort > 0) and zoneOrSort or nil
    return {
        id = questId,
        name = name,
        level = db.Quest.questLevel(questId),
        requiredLevel = db.Quest.requiredLevel(questId),
        zoneId = zoneId,
        zoneName = Util.GetAreaName(zoneId),
    }
end

--------------------------------------------------------------------------------------------
-- Enemies
--------------------------------------------------------------------------------------------

-- Collects NPCs into one group, merging NPCs that share a name (the macro targets by name).
local function NewCollector(db, questZoneId)
    local byName, list = {}, {}
    local collector = {}

    function collector.Add(npcId)
        if type(npcId) ~= "number" then
            return
        end
        local name = db.Npc.name(npcId)
        if type(name) ~= "string" or name == "" then
            return
        end
        local minLevel, maxLevel = db.Npc.minLevel(npcId), db.Npc.maxLevel(npcId)
        local zoneId = db.Npc.zoneID(npcId)
        local enemy = byName[name]
        if not enemy then
            enemy = {
                name = name,
                npcId = npcId,
                npcIds = {},
                minLevel = minLevel,
                maxLevel = maxLevel,
                rank = db.Npc.rank(npcId),
                zoneId = zoneId,
                inQuestZone = false,
            }
            byName[name] = enemy
            list[#list + 1] = enemy
        else
            if minLevel and (not enemy.minLevel or minLevel < enemy.minLevel) then
                enemy.minLevel = minLevel
            end
            if maxLevel and (not enemy.maxLevel or maxLevel > enemy.maxLevel) then
                enemy.maxLevel = maxLevel
            end
            enemy.zoneId = enemy.zoneId or zoneId
        end
        for _, known in ipairs(enemy.npcIds) do
            if known == npcId then
                return
            end
        end
        enemy.npcIds[#enemy.npcIds + 1] = npcId
        if questZoneId and zoneId == questZoneId then
            enemy.inQuestZone = true
        end
    end

    function collector.Finish()
        for _, enemy in ipairs(list) do
            table.sort(enemy.npcIds)
            enemy.npcId = enemy.npcIds[1]
        end
        table.sort(list, QuestData.CompareEnemies)
        return list
    end

    return collector
end

--- Quest zone first, then lowest level (unknown last), then name, then NPC ID.
---@param a GirthBindEnemy
---@param b GirthBindEnemy
---@return boolean
function QuestData.CompareEnemies(a, b)
    if a.inQuestZone ~= b.inQuestZone then
        return a.inQuestZone
    end
    local la, lb = a.minLevel or math.huge, b.minLevel or math.huge
    if la ~= lb then
        return la < lb
    end
    if a.name ~= b.name then
        return a.name < b.name
    end
    return (a.npcId or 0) < (b.npcId or 0)
end

local function NonEmpty(text)
    if type(text) == "string" and text ~= "" then
        return text
    end
    return nil
end

local function BuildGroups(db, questId)
    local groups = {}
    local objectives = db.Quest.objectives(questId) or {}
    local questZoneId = db.Quest.zoneOrSort(questId)
    if type(questZoneId) ~= "number" or questZoneId <= 0 then
        questZoneId = nil
    end

    local function AddGroup(kind, label, count, fill)
        local collector = NewCollector(db, questZoneId)
        fill(collector.Add)
        groups[#groups + 1] = {
            kind = kind,
            label = label or L["OBJECTIVE_UNNAMED"],
            count = type(count) == "number" and count > 0 and count or nil,
            enemies = collector.Finish(),
        }
    end

    for _, objective in ipairs(objectives[1] or {}) do
        local npcId = objective[1]
        AddGroup("kill", NonEmpty(objective[2]) or db.Npc.name(npcId), objective[3], function(add)
            add(npcId)
        end)
    end

    for _, objective in ipairs(objectives[5] or {}) do
        local npcIds, rootNpcId = objective[1], objective[2]
        AddGroup("killCredit", NonEmpty(objective[3]) or db.Npc.name(rootNpcId), objective[4], function(add)
            for _, npcId in ipairs(type(npcIds) == "table" and npcIds or {}) do
                add(npcId)
            end
        end)
    end

    for _, objective in ipairs(objectives[3] or {}) do
        local itemId = objective[1]
        AddGroup("item", NonEmpty(objective[2]) or db.Item.name(itemId), objective[3], function(add)
            for _, npcId in ipairs(db.Item.npcDrops(itemId) or {}) do
                add(npcId)
            end
        end)
    end

    for _, extra in ipairs(db.Quest.extraObjectives(questId) or {}) do
        local monsters = {}
        for _, ref in ipairs(type(extra[5]) == "table" and extra[5] or {}) do
            if type(ref) == "table" and ref[1] == "monster" then
                monsters[#monsters + 1] = ref[2]
            end
        end
        if #monsters > 0 then
            AddGroup("special", NonEmpty(extra[3]), nil, function(add)
                for _, npcId in ipairs(monsters) do
                    add(npcId)
                end
            end)
        end
    end

    return groups
end

--- The quest's objectives that involve enemies, each with its enemies. Objectives with no
--- enemy source (e.g. an item only gathered from objects) appear with an empty list.
---@param questId integer
---@return GirthBindEnemyGroup[]
function QuestData.GetEnemyGroups(questId)
    local db = DB()
    if not db or type(questId) ~= "number" or not db.Quest.name(questId) then
        return {}
    end
    local groups = cache[questId]
    if not groups then
        groups = BuildGroups(db, questId)
        cache[questId] = groups
    end
    return groups
end

--- Every distinct enemy across the quest's groups, in group order, de-duplicated by name.
---@param questId integer
---@return GirthBindEnemy[]
function QuestData.GetEnemies(questId)
    local list, seen = {}, {}
    for _, group in ipairs(QuestData.GetEnemyGroups(questId)) do
        for _, enemy in ipairs(group.enemies) do
            if not seen[enemy.name] then
                seen[enemy.name] = true
                list[#list + 1] = enemy
            end
        end
    end
    return list
end

---@param questId integer
---@return boolean
function QuestData.HasEnemies(questId)
    return #QuestData.GetEnemies(questId) > 0
end
