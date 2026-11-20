local Loader = require("loader")
local FakeQuestieDB = require("questiedb")

describe("Lookup window", function()
    local ns, Wow, Lookup

    local function load(db)
        ns, Wow = Loader.Load({ questieDB = db })
        Lookup = ns.Lookup
        Wow.questLog = {
            { isHeader = true, title = "Elwynn Forest" },
            { questID = 7, title = "Kobold Camp Cleanup", level = 4 },
            { questID = 33, title = "Wolves Across the Border", level = 6, complete = true },
            { questID = 99, title = "Hidden", isHidden = true },
            { isHeader = true, title = "Empty Header" },
        }
    end

    local function kinds(rows)
        local list = {}
        for index, row in ipairs(rows) do
            list[index] = row.kind
        end
        return list
    end

    describe("quest rows", function()
        it("shows the quest log, with headers, for an empty query", function()
            load(FakeQuestieDB.Sample())
            local rows, status = Lookup.BuildQuestRows("  ")
            assert.are.same({ "header", "quest", "quest" }, kinds(rows))
            assert.are.equal("Elwynn Forest", rows[1].text)
            assert.are.same({ kind = "quest", id = 33, text = "Wolves Across the Border", level = 6, isComplete = true }, rows[3])
            assert.are.equal("Your quest log (2)", status)
        end)

        it("still lists the quest log without QuestieDB, with QuestieDB's reason", function()
            load(nil)
            local rows, status = Lookup.BuildQuestRows("")
            assert.are.equal(3, #rows)
            assert.matches("needs the QuestieDB addon", status)
            rows, status = Lookup.BuildQuestRows("kobold")
            assert.are.same({}, rows)
            assert.matches("needs the QuestieDB addon", status)
        end)

        it("reports indexing progress until the index is ready", function()
            load(FakeQuestieDB.Sample())
            local rows, status = Lookup.BuildQuestRows("kobold")
            assert.are.same({}, rows)
            assert.are.equal("Indexing quests... 0%", status)
        end)

        it("lists search results with match counts", function()
            load(FakeQuestieDB.Sample())
            ns.QuestSearch.BuildSync()
            local rows, status = Lookup.BuildQuestRows("defias")
            assert.are.equal(4, #rows)
            assert.are.same({ kind = "quest", id = 3003, text = "Defias Brotherhood Ledger", level = 15 }, rows[1])
            assert.are.equal("4 matching quests", status)
            rows, status = Lookup.BuildQuestRows("zzz")
            assert.are.same({}, rows)
            assert.are.equal("No quests match.", status)
        end)

        it("says when results are truncated", function()
            load(FakeQuestieDB.Sample())
            ns.QuestSearch.BuildSync()
            ns.QuestSearch.DEFAULT_LIMIT = 2
            local rows, status = Lookup.BuildQuestRows("defias")
            assert.are.equal(2, #rows)
            assert.are.equal("Showing the first 2 of 4 matches", status)
        end)
    end)

    describe("enemy rows", function()
        before_each(function()
            load(FakeQuestieDB.Sample())
        end)

        it("asks for a quest when none is selected", function()
            assert.are.same({ { kind = "note", text = "Pick a quest to see its enemies." } }, Lookup.BuildEnemyRows(nil))
        end)

        it("groups enemies under their objectives, with notes for empty ones", function()
            local rows = Lookup.BuildEnemyRows(47)
            assert.are.same({
                "group", "enemy", "enemy", "enemy",
                "group", "enemy", "enemy",
                "group", "note",
                "group", "enemy",
            }, kinds(rows))
        end)

        it("collapses long objectives behind a Show more row, and expands them", function()
            Lookup.COLLAPSE_AT = 2
            local rows = Lookup.BuildEnemyRows(33)
            assert.are.same({ "group", "enemy", "enemy", "more" }, kinds(rows))
            assert.are.same({ kind = "more", groupIndex = 1, hidden = 2 }, rows[4])
            assert.are.same({ "group", "enemy", "enemy", "enemy", "enemy" }, kinds(Lookup.BuildEnemyRows(33, { [1] = true })))
        end)

        it("marks the bound enemy", function()
            ns.Macro:Bind({ name = "Timber Wolf" })
            local rows = Lookup.BuildEnemyRows(33)
            assert.is_false(rows[2].isBound)
            assert.is_true(rows[3].isBound)
        end)

        it("explains quests with no enemies and unknown quests", function()
            assert.are.equal("This quest has no enemies to bind.", Lookup.BuildEnemyRows(46)[1].text)
            assert.are.equal("QuestieDB has no quest with ID 424242.", Lookup.BuildEnemyRows(424242)[1].text)
        end)

        it("describes enemies and quests", function()
            local enemy = ns.QuestData.GetEnemyGroups(47)[1].enemies[3]
            assert.are.equal("Level 5-6 · Elite · Elwynn Forest", Lookup.DescribeEnemy(enemy))
            assert.are.equal("Level 4 (requires 2) · Elwynn Forest · Quest 7 · In your quest log",
                Lookup.DescribeQuest(ns.QuestData.GetQuest(7)))
            assert.are.equal("Level 14 · Westfall · Quest 3000", Lookup.DescribeQuest(ns.QuestData.GetQuest(3000)))
        end)
    end)

    describe("opening", function()
        before_each(function()
            load(FakeQuestieDB.Sample())
            -- Skip building real frames: Open only needs Show/Raise from the window frame.
            local frame = CreateFrame("Frame")
            Lookup.GetFrame = function(self)
                self.frame = frame
                return frame
            end
        end)

        it("opens on a quest", function()
            Lookup:Open({ questId = 33 })
            assert.is_true(Lookup:IsShown())
            assert.are.equal(33, Lookup.selectedQuestId)
            assert.are.equal("", Lookup.query)
        end)

        it("opens directly on the only exact name match once the index is ready", function()
            Lookup:Open({ query = "kobold camp cleanup", exact = true })
            assert.are.equal("kobold camp cleanup", Lookup.query)
            assert.is_nil(Lookup.selectedQuestId)
            Wow.FlushTimers()
            assert.are.equal(7, Lookup.selectedQuestId)
        end)

        it("leaves the results list when several quests share the name", function()
            Lookup:Open({ query = "The Defias Brotherhood", exact = true })
            Wow.FlushTimers()
            assert.is_nil(Lookup.selectedQuestId)
            assert.are.equal("The Defias Brotherhood", Lookup.query)
        end)

        it("shows the quest log for a bare open", function()
            Lookup:Open({ query = "kobold" })
            Lookup:Open()
            assert.are.equal("", Lookup.query)
        end)
    end)
end)

describe("Lookup window frame", function()
    it("builds the real window and runs its first OnShow", function()
        local ns, Wow = Loader.Load({ questieDB = FakeQuestieDB.Sample() })
        -- Enough of ScrollBox for GetFrame's construction path; the fake accepts other widget calls.
        _G.CreateScrollBoxListLinearView = function()
            return setmetatable({}, { __index = function() return function() end end })
        end
        _G.ScrollUtil = { InitScrollBoxListWithScrollBar = function() end }
        _G.CreateDataProvider = function(rows)
            return rows
        end
        ns.Macro:Bind({ name = "Boar" })
        ns.Lookup:Open({ questId = 7 })

        assert.are.same({}, Wow.errors)
        assert.is_true(ns.Lookup:IsShown())
        assert.are.equal("Kobold Camp Cleanup", ns.Lookup.questTitle:GetText())
        local footer = ns.Lookup.footerText:GetText():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        assert.are.equal("The GirthBind macro targets Boar.", footer)
        local listening = false
        for _, frame in ipairs(Wow.frames) do
            listening = listening or frame:IsEventRegistered("QUEST_LOG_UPDATE")
        end
        assert.is_true(listening)
        assert.are.equal("GirthBindLookupFrame", UISpecialFrames[1])

        ns.Lookup:Close()
        assert.is_false(ns.Lookup:IsShown())
    end)
end)
