local Loader = require("loader")
local FakeQuestieDB = require("questiedb")

describe("QuestSearch", function()
    local ns, Wow, QuestSearch, db

    before_each(function()
        db = FakeQuestieDB.Sample()
        ns, Wow = Loader.Load({ questieDB = db })
        QuestSearch = ns.QuestSearch
        QuestSearch.Reset()
    end)

    local function ids(results)
        local list = {}
        for index, entry in ipairs(results) do
            list[index] = entry.id
        end
        return list
    end

    it("finds nothing before the index exists", function()
        assert.is_false(QuestSearch.IsReady())
        assert.are.same({}, (QuestSearch.Search("kobold")))
    end)

    it("matches substrings case-insensitively", function()
        QuestSearch.BuildSync()
        assert.are.same({ 7 }, ids((QuestSearch.Search("CAMP"))))
        assert.are.same({}, (QuestSearch.Search("   ")))
    end)

    it("ranks exact names, then prefixes, then other matches", function()
        QuestSearch.BuildSync()
        local results, total = QuestSearch.Search("the defias brotherhood")
        assert.are.same({ 3000, 3001, 3002 }, ids(results))
        assert.are.equal(3, total)

        results = QuestSearch.Search("defias")
        -- "Defias Brotherhood Ledger" starts with the query; the others only contain it.
        assert.are.same({ 3003, 3000, 3001, 3002 }, ids(results))
    end)

    it("limits results but reports the full count", function()
        QuestSearch.BuildSync()
        local results, total = QuestSearch.Search("o", 2)
        assert.are.equal(2, #results)
        assert.is_true(total > 2)
    end)

    it("finds exact names ignoring case", function()
        QuestSearch.BuildSync()
        assert.are.same({ 3000, 3001, 3002 }, QuestSearch.FindExact("The Defias Brotherhood"))
        assert.are.same({ 7 }, QuestSearch.FindExact("  kobold camp cleanup "))
        assert.are.same({}, QuestSearch.FindExact("Kobold Camp"))
    end)

    it("builds across frames, reporting progress, and runs callbacks once ready", function()
        QuestSearch.SLICE_MS = 3 -- the fake clock advances 1ms per read
        local progress, done = {}, 0
        QuestSearch.Build(function()
            done = done + 1
        end, function(fraction)
            progress[#progress + 1] = fraction
        end)
        assert.is_true(QuestSearch.IsBuilding())
        assert.is_false(QuestSearch.IsReady())

        QuestSearch.Build(function()
            done = done + 1
        end)
        Wow.FlushTimers()

        assert.is_true(QuestSearch.IsReady())
        assert.are.equal(2, done)
        assert.is_true(#progress > 0)
        for index = 2, #progress do
            assert.is_true(progress[index] >= progress[index - 1])
        end
        assert.are.equal(1, QuestSearch.GetProgress())

        -- Already built: the callback runs right away.
        QuestSearch.Build(function()
            done = done + 1
        end)
        assert.are.equal(3, done)
    end)

    it("reads each quest name once while building", function()
        local before = db.reads
        QuestSearch.BuildSync()
        assert.are.equal(#db.Quest.GetAllIds(), db.reads - before)
    end)
end)
