local Loader = require("loader")
local FakeQuestieDB = require("questiedb")

describe("QuestData", function()
    local ns, QuestData

    local function load(db)
        ns = Loader.Load({ questieDB = db })
        QuestData = ns.QuestData
    end

    local function names(enemies)
        local list = {}
        for index, enemy in ipairs(enemies) do
            list[index] = enemy.name
        end
        return list
    end

    describe("status", function()
        it("is missing without QuestieDB, and reads return nothing", function()
            load(nil)
            local status, message = QuestData.GetStatus()
            assert.are.equal("missing", status)
            assert.matches("QuestieDB", message)
            assert.is_nil(QuestData.GetQuest(7))
            assert.are.same({}, QuestData.GetEnemyGroups(7))
            assert.are.same({}, QuestData.GetAllQuestIds())
        end)

        it("is incompatible when the contract doesn't match", function()
            load(FakeQuestieDB.New({ contract = 5, quests = { [7] = { name = "x" } } }))
            local status, message = QuestData.GetStatus()
            assert.are.equal("incompatible", status)
            assert.matches("wrong version", message)
            assert.is_nil(QuestData.GetQuest(7))
        end)

        it("is ok with a contract 4 QuestieDB", function()
            load(FakeQuestieDB.Sample())
            assert.are.equal("ok", (QuestData.GetStatus()))
            assert.is_true(QuestData.IsAvailable())
        end)
    end)

    describe("quests", function()
        before_each(function()
            load(FakeQuestieDB.Sample())
        end)

        it("reads quest info with the zone name", function()
            assert.are.same({
                id = 7,
                name = "Kobold Camp Cleanup",
                level = 4,
                requiredLevel = 2,
                zoneId = 12,
                zoneName = "Elwynn Forest",
            }, QuestData.GetQuest(7))
        end)

        it("returns nil for unknown quests", function()
            assert.is_nil(QuestData.GetQuest(999999))
            assert.are.same({}, QuestData.GetEnemyGroups(999999))
        end)
    end)

    describe("enemy groups", function()
        before_each(function()
            load(FakeQuestieDB.Sample())
        end)

        it("lists kill objectives", function()
            local groups = QuestData.GetEnemyGroups(7)
            assert.are.equal(1, #groups)
            assert.are.equal("kill", groups[1].kind)
            assert.are.equal("Kobold Vermin", groups[1].label)
            assert.are.equal(10, groups[1].count)
            assert.are.same({ "Kobold Vermin" }, names(groups[1].enemies))
            assert.are.same({ 6 }, groups[1].enemies[1].npcIds)
        end)

        it("lists item droppers, quest zone first, then by level", function()
            local group = QuestData.GetEnemyGroups(33)[1]
            assert.are.equal("item", group.kind)
            assert.are.equal("Tough Wolf Meat", group.label)
            assert.are.equal(8, group.count)
            -- Riverpaw Gnoll (Westfall) sorts after every Elwynn wolf despite its level.
            assert.are.same({ "Young Wolf", "Timber Wolf", "Gray Forest Wolf", "Riverpaw Gnoll" }, names(group.enemies))
            assert.is_true(group.enemies[1].inQuestZone)
            assert.is_false(group.enemies[4].inQuestZone)
        end)

        it("merges NPCs that share a name into one enemy", function()
            local groups = QuestData.GetEnemyGroups(47)
            local bandana = groups[2]
            assert.are.equal("item", bandana.kind)
            assert.are.equal("Red Bandana", bandana.label) -- objective text wins over the item name
            assert.are.same({ "Defias Bandit", "Defias Knuckleduster" }, names(bandana.enemies))
            local bandit = bandana.enemies[1]
            assert.are.same({ 116, 1116 }, bandit.npcIds)
            assert.are.equal(116, bandit.npcId)
            assert.are.equal(9, bandit.minLevel)
            assert.are.equal(12, bandit.maxLevel)
            assert.is_true(bandit.inQuestZone)
        end)

        it("orders kill, kill credit, item, then special objectives", function()
            local kinds = {}
            for index, group in ipairs(QuestData.GetEnemyGroups(47)) do
                kinds[index] = group.kind
            end
            assert.are.same({ "killCredit", "item", "item", "special" }, kinds)
        end)

        it("lists every NPC that grants kill credit", function()
            local credit = QuestData.GetEnemyGroups(47)[1]
            assert.are.equal("Kobolds slain", credit.label)
            assert.are.equal(12, credit.count)
            assert.are.same({ "Kobold Worker", "Kobold Tunneler", "Kobold Geomancer" }, names(credit.enemies))
            assert.are.equal(1, credit.enemies[3].rank)
        end)

        it("keeps an objective with no enemy source as an empty group", function()
            local scrap = QuestData.GetEnemyGroups(47)[3]
            assert.are.equal("Linen Scrap", scrap.label)
            assert.are.same({}, scrap.enemies)
        end)

        it("takes monster references from special objectives and skips objects", function()
            local special = QuestData.GetEnemyGroups(47)[4]
            assert.are.equal("special", special.kind)
            assert.are.equal("Ambush the Defias", special.label)
            assert.are.same({ "Defias Bandit" }, names(special.enemies))
        end)

        it("de-duplicates enemies across objectives for menus", function()
            assert.are.same({
                "Kobold Worker", "Kobold Tunneler", "Kobold Geomancer", "Defias Bandit", "Defias Knuckleduster",
            }, names(QuestData.GetEnemies(47)))
            assert.is_true(QuestData.HasEnemies(47))
            assert.is_false(QuestData.HasEnemies(46))
        end)

        it("caches groups per quest", function()
            local first = QuestData.GetEnemyGroups(7)
            assert.are.equal(first, QuestData.GetEnemyGroups(7))
            QuestData.ClearCache()
            local rebuilt = QuestData.GetEnemyGroups(7)
            assert.are_not.equal(first, rebuilt)
            assert.are.same(first, rebuilt)
        end)
    end)
end)
