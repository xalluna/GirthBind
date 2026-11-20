local Loader = require("loader")

describe("Database", function()
    it("starts with defaults", function()
        local ns = Loader.Load()
        local global = ns.db.global
        assert.are.equal("GirthBind", global.macro.name)
        assert.are.equal(ns.Template.DEFAULT_BODY, global.macro.body)
        assert.are.equal("none", global.debugLevel)
        assert.is_nil(global.bound)
        assert.are.equal(1, global.schemaVersion)
    end)

    it("keeps valid saved settings", function()
        local ns = Loader.Load({
            savedVariables = {
                global = {
                    macro = { name = "Hunt", body = "/tar $Target.Name$" },
                    bound = { name = "Young Wolf", npcId = 299 },
                    debugLevel = "info",
                },
            },
        })
        local global = ns.db.global
        assert.are.equal("Hunt", global.macro.name)
        assert.are.equal("/tar $Target.Name$", global.macro.body)
        assert.are.same({ name = "Young Wolf", npcId = 299 }, global.bound)
        assert.are.equal("info", global.debugLevel)
    end)

    it("repairs invalid saved settings", function()
        local ns = Loader.Load({
            savedVariables = {
                global = {
                    macro = { name = "   ", body = 42 },
                    bound = { name = "" },
                    debugLevel = "loud",
                    window = { point = "CENTER" },
                },
            },
        })
        local global = ns.db.global
        assert.are.equal("GirthBind", global.macro.name)
        assert.are.equal(ns.Template.DEFAULT_BODY, global.macro.body)
        assert.is_nil(global.bound)
        assert.are.equal("none", global.debugLevel)
        assert.are.same({ point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }, global.window)
    end)

    it("drops the old design's Current/Previous fields by never reading them", function()
        local ns = Loader.Load({ savedVariables = { global = { Current = { Name = "Old" } } } })
        assert.is_nil(ns.db.global.bound)
    end)

    it("validates macro names by character count", function()
        local ns = Loader.Load({ login = false })
        local Database = ns.Database
        assert.is_true(Database.IsValidMacroName("GirthBind"))
        assert.is_true(Database.IsValidMacroName(string.rep("a", 16)))
        assert.is_false(Database.IsValidMacroName(string.rep("a", 17)))
        assert.is_false(Database.IsValidMacroName(""))
        assert.is_false(Database.IsValidMacroName(nil))
    end)
end)
