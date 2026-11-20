-- A fake LibQuestieDB (contract 4 read API) built from plain fixture tables.

local FakeQuestieDB = {}

---@param data { contract: integer?, quests: table<integer, table>?, npcs: table<integer, table>?, items: table<integer, table>? }
function FakeQuestieDB.New(data)
    data = data or {}
    local quests, npcs, items = data.quests or {}, data.npcs or {}, data.items or {}
    local contract = data.contract or 4

    local function Field(source, field)
        return function(id)
            local row = source[id]
            return row and row[field]
        end
    end

    local db = {
        contractVersion = contract,
        reads = 0,
    }

    function db.RequireContract(required)
        if required == contract then
            return true
        end
        return false, ("QuestieDB contract mismatch: needs %s, provides %s"):format(required, contract)
    end

    db.Quest = {
        name = function(id)
            db.reads = db.reads + 1
            local row = quests[id]
            return row and row.name
        end,
        questLevel = Field(quests, "level"),
        requiredLevel = Field(quests, "requiredLevel"),
        zoneOrSort = Field(quests, "zone"),
        extraObjectives = Field(quests, "extra"),
        objectives = function(id)
            local row = quests[id]
            if not row then
                return nil
            end
            return row.objectives or {}
        end,
        GetAllIds = function()
            local ids = {}
            for id in pairs(quests) do
                ids[#ids + 1] = id
            end
            table.sort(ids)
            return ids
        end,
    }

    db.Npc = {
        name = Field(npcs, "name"),
        minLevel = Field(npcs, "minLevel"),
        maxLevel = Field(npcs, "maxLevel"),
        rank = Field(npcs, "rank"),
        zoneID = Field(npcs, "zone"),
    }

    db.Item = {
        name = Field(items, "name"),
        npcDrops = Field(items, "drops"),
    }

    return db
end

--- A small, realistic data set: Elwynn quests with kills, kill credit, item drops, and a
--- special objective.
function FakeQuestieDB.Sample()
    return FakeQuestieDB.New({
        npcs = {
            [6] = { name = "Kobold Vermin", minLevel = 1, maxLevel = 2, zone = 12 },
            [257] = { name = "Kobold Worker", minLevel = 3, maxLevel = 4, zone = 12 },
            [475] = { name = "Kobold Tunneler", minLevel = 4, maxLevel = 5, zone = 12 },
            [476] = { name = "Kobold Geomancer", minLevel = 5, maxLevel = 6, zone = 12, rank = 1 },
            [299] = { name = "Young Wolf", minLevel = 1, maxLevel = 2, zone = 12 },
            [69] = { name = "Timber Wolf", minLevel = 2, maxLevel = 3, zone = 12 },
            [1922] = { name = "Gray Forest Wolf", minLevel = 8, maxLevel = 9, zone = 12 },
            [500] = { name = "Riverpaw Gnoll", minLevel = 10, maxLevel = 11, zone = 40 },
            [116] = { name = "Defias Bandit", minLevel = 9, maxLevel = 10, zone = 12 },
            [1116] = { name = "Defias Bandit", minLevel = 11, maxLevel = 12, zone = 40 },
            [449] = { name = "Defias Knuckleduster", minLevel = 9, maxLevel = 10, zone = 12 },
            [900] = { name = "Bounty Board", zone = 12 },
        },
        items = {
            [750] = { name = "Tough Wolf Meat", drops = { 1922, 69, 299, 500 } },
            [1000] = { name = "Red Burlap Bandana", drops = { 116, 1116, 449 } },
            [2000] = { name = "Linen Scrap", drops = {} },
        },
        quests = {
            [7] = {
                name = "Kobold Camp Cleanup",
                level = 4,
                requiredLevel = 2,
                zone = 12,
                objectives = { { { 6, nil, 10 } } },
            },
            [15] = {
                name = "Investigate Echo Ridge",
                level = 5,
                zone = 12,
                objectives = { { { 257, nil, 10 } } },
            },
            [33] = {
                name = "Wolves Across the Border",
                level = 6,
                zone = 12,
                objectives = { nil, nil, { { 750, nil, 8 } } },
            },
            [46] = {
                name = "Bounty on Murlocs",
                level = 10,
                zone = 12,
                objectives = {},
            },
            [47] = {
                name = "Gold Dust Exchange",
                level = 7,
                zone = 12,
                objectives = {
                    nil,
                    nil,
                    { { 1000, "Red Bandana", 15 }, { 2000, nil, 5 } },
                    nil,
                    { { { 475, 476, 257 }, 475, "Kobolds slain", 12 } },
                },
                extra = { { nil, 1, "Ambush the Defias", 1, { { "monster", 116 }, { "object", 900 } } } },
            },
            [3000] = { name = "The Defias Brotherhood", level = 14, zone = 40, objectives = {} },
            [3001] = { name = "The Defias Brotherhood", level = 16, zone = 40, objectives = {} },
            [3002] = { name = "the defias brotherhood", level = 18, zone = 40, objectives = {} },
            [3003] = { name = "Defias Brotherhood Ledger", level = 15, zone = 40, objectives = {} },
        },
    })
end

return FakeQuestieDB
