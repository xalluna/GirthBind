local Loader = require("loader")
local FakeQuestieDB = require("questiedb")

describe("Commands", function()
    local ns, Wow, opened

    local function load(db)
        ns, Wow = Loader.Load({ questieDB = db })
        opened = {}
        -- The window itself needs real frames; record what it was asked to show.
        ns.Lookup.Open = function(_, options)
            opened[#opened + 1] = options or {}
        end
    end

    local function run(input)
        SlashCmdList.ACECONSOLE_GB(input)
    end

    before_each(function()
        load(FakeQuestieDB.Sample())
    end)

    it("parses the command and keeps the argument's case", function()
        assert.are.same({ "lookup", "The Defias Brotherhood" }, { ns.Commands.Parse("  LOOKUP   The Defias Brotherhood  ") })
        assert.are.same({ "", "" }, { ns.Commands.Parse(nil) })
    end)

    it("opens the window for a bare /gb and /gb lookup", function()
        run("")
        run("lookup")
        assert.are.same({ {}, {} }, opened)
    end)

    it("searches by name with /gb lookup <name>", function()
        run('lookup "Kobold Camp Cleanup"')
        assert.are.same({ { query = "Kobold Camp Cleanup", exact = true } }, opened)
    end)

    it("still opens the window (which explains) when QuestieDB is missing", function()
        load(nil)
        run("lookup Kobold")
        assert.are.equal(1, #opened)
        assert.matches("needs the QuestieDB addon", Wow.ChatText())
    end)

    it("opens a quest by ID", function()
        run("idlookup 7")
        run("idlookup #15")
        assert.are.same({ { questId = 7 }, { questId = 15 } }, opened)
    end)

    it("rejects bad or unknown quest IDs", function()
        run("idlookup")
        run("idlookup abc")
        run("idlookup 424242")
        assert.are.same({}, opened)
        assert.matches("Usage: /gb idlookup <questId>", Wow.ChatText())
        assert.matches("no quest with ID 424242", Wow.ChatText())
    end)

    it("explains idlookup without QuestieDB", function()
        load(nil)
        run("idlookup 7")
        assert.are.same({}, opened)
        assert.matches("needs the QuestieDB addon", Wow.ChatText())
    end)

    it("binds the current target", function()
        Wow.target = { name = "Young Wolf", guid = "Creature-0-1-2-3-299-00001" }
        run("bind")
        assert.are.same({ name = "Young Wolf", npcId = 299 }, ns.Macro:GetBound())
    end)

    it("picks up the macro", function()
        run("pickup")
        assert.are.same({ macro = 1 }, Wow.cursor)
    end)

    it("opens the options page", function()
        run("options")
        assert.are.equal("category-GirthBind", Wow.openedCategory)
        Wow.openedCategory = nil
        run("config")
        assert.are.equal("category-GirthBind", Wow.openedCategory)
    end)

    it("shows and sets the debug level", function()
        run("debug")
        assert.matches("Debug level is none", Wow.ChatText())
        run("debug INFO")
        assert.are.equal("info", ns.db.global.debugLevel)
        run("debug loud")
        assert.are.equal("info", ns.db.global.debugLevel)
        assert.matches("Unknown debug level loud", Wow.ChatText())
    end)

    it("prints help for help, ?, and unknown commands", function()
        run("help")
        assert.matches("/gb idlookup <questId>", Wow.ChatText())
        Wow.chat = {}
        run("rename Foo")
        assert.matches("Unknown command rename", Wow.ChatText())
        assert.matches("/gb pickup %- put the GirthBind macro on your cursor", Wow.ChatText())
        Wow.chat = {}
        run("mark skull")
        assert.matches("Unknown command mark", Wow.ChatText())
    end)

    it("doesn't register the old /girthbinder command", function()
        assert.is_nil(_G.SLASH_GIRTHBINDER1)
        assert.is_nil(SlashCmdList.GIRTHBINDER)
    end)
end)
