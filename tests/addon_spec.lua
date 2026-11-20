local Loader = require("loader")
local FakeQuestieDB = require("questiedb")

describe("Addon lifecycle", function()
    it("loads, initializes SavedVariables, and registers /gb", function()
        local ns, Wow = Loader.Load({ questieDB = FakeQuestieDB.Sample() })
        assert.is_table(ns.db)
        assert.are.equal("GirthBind", ns.db.global.macro.name)
        assert.are.equal("GirthBindDB", ns.SV_NAME)
        assert.are.equal("/gb", _G.SLASH_ACECONSOLE_GB1)
        assert.are.same({}, Wow.errors)
    end)

    it("registers the options page and the Blizzard menu hooks", function()
        local _, Wow, aceConfig = Loader.Load()
        assert.are.equal("GirthBind", aceConfig.optionsApp)
        assert.are.equal("GirthBind", aceConfig.panelName)
        assert.is_function(Wow.menuCallbacks.MENU_QUEST_OBJECTIVE_TRACKER)
        assert.is_function(Wow.menuCallbacks.MENU_QUEST_MAP_LOG_TITLE)
    end)

    it("runs every file without missing locale strings", function()
        local _, Wow = Loader.Load()
        for _, err in ipairs(Wow.errors) do
            assert.is_nil(err:match("Missing entry"), err)
        end
    end)

    describe("dev copy (GirthBind.Test)", function()
        it("uses its own SavedVariables and runs when the release isn't installed", function()
            local ns = Loader.Load({ addonName = "GirthBind.Test" })
            assert.are.equal("GirthBindTestDB", ns.SV_NAME)
            assert.is_false(ns.IS_RELEASE)
            assert.is_table(ns.db)
            assert.are.equal("/gb", _G.SLASH_ACECONSOLE_GB1)
        end)

        it("yields when the release build is enabled", function()
            local ns, Wow, aceConfig = Loader.Load({
                addonName = "GirthBind.Test",
                addons = { GirthBind = { enabled = true } },
            })
            assert.is_true(ns.yielded)
            assert.is_nil(ns.db)
            assert.is_nil(_G.SLASH_ACECONSOLE_GB1)
            assert.is_nil(aceConfig.optionsApp)
            assert.is_nil(Wow.menuCallbacks.MENU_QUEST_OBJECTIVE_TRACKER)
            assert.matches("this dev copy is turned off", Wow.ChatText())
            assert.are.same({}, Wow.errors)
        end)

        it("yields when the release build is already loaded", function()
            local ns = Loader.Load({
                addonName = "GirthBind.Test",
                addons = { GirthBind = { loaded = true } },
            })
            assert.is_true(ns.yielded)
        end)

        it("doesn't yield to a release build that's disabled", function()
            local ns = Loader.Load({
                addonName = "GirthBind.Test",
                addons = { GirthBind = { enabled = false } },
            })
            assert.is_nil(ns.yielded)
            assert.is_table(ns.db)
        end)
    end)

    it("the release build never yields", function()
        local ns = Loader.Load({ addons = { GirthBind = { enabled = true, loaded = true } } })
        assert.is_nil(ns.yielded)
    end)
end)
