-- Quest/QuestSearch.lua
--
-- Case-insensitive quest name search. QuestieDB's own name index only matches exact names, so
-- this keeps a lowercase index of every quest name. Building it reads every quest once, so it
-- runs in time-boxed slices across frames (Build) the first time the lookup window needs it.

---@type string, GirthBindNamespace
local _, ns = ...
local Log, QuestData = ns.Log, ns.QuestData

---@class GirthBindQuestSearch
local QuestSearch = {}
ns.QuestSearch = QuestSearch

QuestSearch.SLICE_MS = 8 -- work per frame while building
QuestSearch.DEFAULT_LIMIT = 200

---@class GirthBindQuestIndexEntry
---@field id integer
---@field name string
---@field lower string

---@type GirthBindQuestIndexEntry[]?
local index
local building = false
local progress = 0
local waiting = {}

---@return boolean
function QuestSearch.IsReady()
    return index ~= nil
end

---@return boolean
function QuestSearch.IsBuilding()
    return building
end

--- 0..1 while building, 1 once ready.
---@return number
function QuestSearch.GetProgress()
    return index and 1 or progress
end

--- Forgets the index (tests, or after QuestieDB data changes).
function QuestSearch.Reset()
    index, building, progress, waiting = nil, false, 0, {}
end

local function Entry(id)
    local name = QuestData.GetQuestName(id)
    if type(name) == "string" and name ~= "" then
        return { id = id, name = name, lower = name:lower() }
    end
    return nil
end

local function Finish(entries)
    index, building, progress = entries, false, 1
    Log.Info("Quest name index ready (%d quests)", #entries)
    local callbacks = waiting
    waiting = {}
    for _, callback in ipairs(callbacks) do
        ns.Util.SafeCall(callback.done)
    end
end

--- Builds the whole index now, in one go.
function QuestSearch.BuildSync()
    local entries = {}
    for _, id in ipairs(QuestData.GetAllQuestIds()) do
        entries[#entries + 1] = Entry(id)
    end
    Finish(entries)
end

--- Builds the index across frames; `done` runs once it's ready (immediately if it already is).
---@param done fun()?
---@param onProgress fun(fraction: number)?
function QuestSearch.Build(done, onProgress)
    if index then
        if done then
            done()
        end
        return
    end
    if done or onProgress then
        waiting[#waiting + 1] = { done = done or function() end, progress = onProgress }
    end
    if building then
        return
    end
    building = true

    local ids = QuestData.GetAllQuestIds()
    local entries, position, total = {}, 1, #ids
    local clock = _G.debugprofilestop

    local function Step()
        local started = clock()
        while position <= total do
            entries[#entries + 1] = Entry(ids[position])
            position = position + 1
            if clock() - started >= QuestSearch.SLICE_MS then
                break
            end
        end
        if position > total then
            Finish(entries)
            return
        end
        progress = (position - 1) / total
        for _, callback in ipairs(waiting) do
            if callback.progress then
                ns.Util.SafeCall(callback.progress, progress)
            end
        end
        C_Timer.After(0, Step)
    end
    Step()
end

local function Rank(entry, query)
    if entry.lower == query then
        return 0
    end
    if entry.lower:sub(1, #query) == query then
        return 1
    end
    return 2
end

--- Quests whose name contains the query (case-insensitive): exact matches first, then names
--- starting with it, then the rest; alphabetical within each, then by ID.
---@param query string
---@param limit integer?
---@return GirthBindQuestIndexEntry[] results At most `limit` entries
---@return integer total Every match, before the limit
function QuestSearch.Search(query, limit)
    local needle = ns.Util.Trim(query):lower()
    if not index or needle == "" then
        return {}, 0
    end
    local matches = {}
    for _, entry in ipairs(index) do
        if entry.lower:find(needle, 1, true) then
            matches[#matches + 1] = { entry = entry, rank = Rank(entry, needle) }
        end
    end
    table.sort(matches, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        if a.entry.lower ~= b.entry.lower then
            return a.entry.lower < b.entry.lower
        end
        return a.entry.id < b.entry.id
    end)
    local results = {}
    for position = 1, math.min(#matches, limit or QuestSearch.DEFAULT_LIMIT) do
        results[position] = matches[position].entry
    end
    return results, #matches
end

--- Every quest ID whose name equals `name`, ignoring case, ascending.
---@param name string
---@return integer[]
function QuestSearch.FindExact(name)
    local needle = ns.Util.Trim(name):lower()
    local ids = {}
    if not index or needle == "" then
        return ids
    end
    for _, entry in ipairs(index) do
        if entry.lower == needle then
            ids[#ids + 1] = entry.id
        end
    end
    table.sort(ids)
    return ids
end
