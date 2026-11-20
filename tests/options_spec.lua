local Loader = require("loader")

describe("Options page", function()
    local ns, Wow, aceConfig, args

    before_each(function()
        ns, Wow, aceConfig = Loader.Load()
        args = aceConfig.optionsTable().args
    end)

    local function name(option)
        return type(option.name) == "function" and option.name() or option.name
    end

    local function plain(text)
        return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end

    it("creates the idle macro when the page is shown", function()
        aceConfig.panel:Hide()
        aceConfig.panel:Show()
        assert.are.equal(1, #Wow.macros)
        assert.are.equal("/stopmacro", Wow.macros[1].body)
    end)

    it("renames the macro through the name field, with validation", function()
        ns.Macro:Bind({ name = "Boar" })
        assert.matches("at most 16", args.macroName.validate(nil, string.rep("n", 17)))
        assert.is_true(args.macroName.validate(nil, "Hunt"))
        args.macroName.set(nil, "Hunt")
        assert.are.equal("Hunt", args.macroName.get())
        assert.are.equal("Hunt", Wow.macros[1].name)
    end)

    it("accepts the name of an existing macro and adopts it", function()
        ns.Macro:Bind({ name = "Boar" })
        Wow.macros[2] = { name = "Taken", icon = 1, body = "/dance" }
        assert.is_true(args.macroName.validate(nil, "Taken"))
        args.macroName.set(nil, "Taken")
        assert.are.equal("Taken", args.macroName.get())
        assert.matches("targetexact Boar", Wow.macros[2].body)
    end)

    it("edits the body template and previews it with the bound enemy", function()
        ns.Macro:Bind({ name = "Boar" })
        args.body.set(nil, "/target $Target.Name$")
        assert.are.equal("/target $Target.Name$", args.body.get())
        assert.are.equal("/target Boar", Wow.macros[1].body)
        local preview = plain(name(args.preview))
        assert.matches("Preview:\n/target Boar\n12 / 255 characters", preview)
    end)

    it("previews with sample values when nothing is bound", function()
        local preview = plain(name(args.preview))
        assert.matches("sample values", preview)
        assert.matches("/targetexact Kobold Vermin", preview)
    end)

    it("rejects a body that renders too long", function()
        assert.matches("limit 255", args.body.validate(nil, string.rep("x", 300)))
    end)

    it("warns about unknown tokens only when there are some", function()
        assert.is_true(args.unknownTokens.hidden())
        args.body.set(nil, "/tar $Target.Nmae$")
        assert.is_false(args.unknownTokens.hidden())
        assert.matches("%$Target%.Nmae%$", plain(name(args.unknownTokens)))
    end)

    it("lists the tokens and the $$ escape", function()
        local tokens = plain(name(args.tokens))
        assert.matches("%$Target%.Name%$  the bound enemy's name", tokens)
        assert.matches("%$%$  a literal dollar sign", tokens)
    end)

    it("resets the body", function()
        args.body.set(nil, "/tar $Target.Name$")
        args.resetBody.func()
        assert.are.equal(ns.Template.DEFAULT_BODY, args.body.get())
    end)

    it("shows and clears the bound enemy", function()
        assert.is_true(args.clear.disabled())
        assert.matches("Nothing is bound", name(args.bound))
        ns.Macro:Bind({ name = "Boar", npcId = 113 })
        assert.matches("Bound: Boar %(NPC 113%)", plain(name(args.bound)))
        assert.is_false(args.clear.disabled())
        args.clear.func()
        assert.is_nil(ns.Macro:GetBound())
    end)

    it("picks up the macro", function()
        args.pickup.func()
        assert.are.same({ macro = 1 }, Wow.cursor)
    end)

    it("sets the debug level from the dropdown", function()
        assert.are.equal("none", args.debugLevel.get())
        assert.are.same({ "log", "info", "warning", "error", "none" }, args.debugLevel.sorting)
        args.debugLevel.set(nil, "warning")
        assert.are.equal("warning", ns.db.global.debugLevel)
    end)

    it("refreshes the page when the macro or bound enemy changes", function()
        local before = aceConfig.notified or 0
        ns.Macro:Bind({ name = "Boar" })
        assert.is_true((aceConfig.notified or 0) > before)
    end)

    it("refuses to open in combat", function()
        Wow.inCombat = true
        assert.is_false(ns.Options:Open())
        assert.is_nil(Wow.openedCategory)
    end)
end)
