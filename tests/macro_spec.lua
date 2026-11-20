local Loader = require("loader")

describe("Macro", function()
    local ns, Wow, Macro

    before_each(function()
        ns, Wow = Loader.Load()
        Macro = ns.Macro
    end)

    local function macro()
        return Wow.macros[GetMacroIndexByName(Macro:GetName())]
    end

    describe("at login", function()
        it("doesn't create the macro (the macro list may not be loaded yet)", function()
            assert.are.equal(0, #Wow.macros)
        end)

        it("brings an existing macro in line with the saved state", function()
            ns, Wow = Loader.Load({
                savedVariables = { global = { bound = { name = "Young Wolf", npcId = 299 } } },
                before = function()
                    Wow.macros[1] = { name = "GirthBind", icon = 1, body = "/stopmacro" }
                end,
            })
            assert.are.equal("/targetexact Young Wolf\n/cleartarget [dead]\n/tm 8", Wow.macros[1].body)
        end)
    end)

    describe("Bind", function()
        it("creates the macro with the rendered template", function()
            assert.is_true(Macro:Bind({ name = "Kobold Vermin", npcId = 6 }))
            assert.are.equal("/targetexact Kobold Vermin\n/cleartarget [dead]\n/tm 8", macro().body)
            assert.are.equal(Macro.ICON, macro().icon)
            assert.are.same({ name = "Kobold Vermin", npcId = 6 }, Macro:GetBound())
            assert.matches("Made a macro named GirthBind that targets Kobold Vermin", Wow.ChatText())
        end)

        it("edits the existing macro in place, keeping its icon", function()
            Macro:Bind({ name = "Kobold Vermin" })
            macro().icon = 999
            Macro:Bind({ name = "Young Wolf" })
            assert.are.equal(1, #Wow.macros)
            assert.are.equal(999, macro().icon)
            assert.matches("targetexact Young Wolf", macro().body)
            assert.matches("GirthBind macro targets Young Wolf", Wow.ChatText())
        end)

        it("trims names and ignores blank ones", function()
            assert.is_true(Macro:Bind({ name = "  Boar  " }))
            assert.are.equal("Boar", Macro:GetBound().name)
            assert.is_false(Macro:Bind({ name = "   " }))
            assert.is_false(Macro:Bind(nil))
            assert.are.equal("Boar", Macro:GetBound().name)
        end)

        it("refuses a bind that would overflow the macro, keeping the old binding", function()
            Macro:Bind({ name = "Boar" })
            ns.db.global.macro.body = string.rep("x", 240) .. "$Target.Name$"
            assert.is_false(Macro:Bind({ name = "A Very Long Enemy Name Indeed" }))
            assert.are.equal("Boar", Macro:GetBound().name)
            assert.matches("limit 255", Wow.ChatText())
        end)

        it("queues the macro edit in combat and applies it when combat ends", function()
            Macro:Bind({ name = "Boar" })
            Wow.inCombat = true
            assert.is_true(Macro:Bind({ name = "Young Wolf" }))
            assert.matches("targetexact Boar", macro().body)
            assert.matches("will update when combat ends", Wow.ChatText())

            Wow.inCombat = false
            Wow.FireEvent("PLAYER_REGEN_ENABLED")
            assert.matches("targetexact Young Wolf", macro().body)
            local last = Wow.LastChat():gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            assert.matches("GirthBind macro targets Young Wolf", last)
        end)

        it("reports a full account macro list and keeps the old binding", function()
            for index = 1, 120 do
                Wow.macros[index] = { name = "M" .. index, icon = 1, body = "" }
            end
            assert.is_false(Macro:Bind({ name = "Boar" }))
            assert.is_nil(Macro:GetBound())
            assert.matches("account macros are full %(120/120%)", Wow.ChatText())
        end)

        it("tells other modules the bound enemy changed", function()
            local seen
            ns.addon:RegisterMessage(ns.MESSAGES.BOUND_CHANGED, function(_, bound)
                seen = bound
            end)
            Macro:Bind({ name = "Boar", npcId = 113 })
            assert.are.same({ name = "Boar", npcId = 113 }, seen)
        end)
    end)

    describe("BindTarget", function()
        it("binds the current target with its NPC ID", function()
            Wow.target = { name = "Kobold Vermin", guid = "Creature-0-1-2-3-6-0000ABCDEF" }
            assert.is_true(Macro:BindTarget())
            assert.are.same({ name = "Kobold Vermin", npcId = 6 }, Macro:GetBound())
        end)

        it("binds a player target by name only", function()
            Wow.target = { name = "Someone", guid = "Player-1-0ABCDEF" }
            assert.is_true(Macro:BindTarget())
            assert.are.same({ name = "Someone" }, Macro:GetBound())
        end)

        it("explains when there's no target", function()
            assert.is_false(Macro:BindTarget())
            assert.matches("don't have a target", Wow.ChatText())
        end)

        it("refuses secret target identities", function()
            Wow.target = { name = "Hidden", guid = "Creature-0-1-2-3-6-0" }
            _G.issecretvalue = function(value)
                return value == "Hidden"
            end
            assert.is_false(Macro:BindTarget())
            assert.is_nil(Macro:GetBound())
            assert.matches("identity is hidden", Wow.ChatText())
        end)
    end)

    describe("Clear", function()
        it("forgets the bound enemy and idles the macro", function()
            Macro:Bind({ name = "Boar" })
            assert.is_true(Macro:Clear())
            assert.is_nil(Macro:GetBound())
            assert.are.equal("/stopmacro", macro().body)
            assert.is_false(Macro:Clear())
        end)
    end)

    describe("template", function()
        it("re-renders the macro immediately with the bound enemy", function()
            Macro:Bind({ name = "Boar" })
            assert.is_true(Macro:SetTemplate("/target $Target.Name$\r\n/startattack"))
            assert.are.equal("/target $Target.Name$\n/startattack", Macro:GetTemplate())
            assert.are.equal("/target Boar\n/startattack", macro().body)
        end)

        it("creates the idle macro when nothing is bound", function()
            assert.is_true(Macro:SetTemplate("/target $Target.Name$"))
            assert.are.equal("/stopmacro", macro().body)
        end)

        it("accepts unknown tokens (they're a warning, not an error)", function()
            assert.is_nil(Macro:ValidateTemplate("/tar $Target.Nmae$"))
        end)

        it("rejects a template that renders too long, using the bound name or the sample", function()
            local long = string.rep("x", 250) .. "$Target.Name$"
            assert.matches("limit 255", Macro:ValidateTemplate(long))
            assert.is_false((Macro:SetTemplate(long)))
            assert.are.equal(ns.Template.DEFAULT_BODY, Macro:GetTemplate())

            local fits = string.rep("x", 240) .. "$Target.Name$" -- 240 + "Kobold Vermin" (13) = 253
            assert.is_nil(Macro:ValidateTemplate(fits))
            Macro:Bind({ name = "Boar" })
            assert.is_nil(Macro:ValidateTemplate(string.rep("x", 251) .. "$Target.Name$"))
        end)

        it("resets to the default body", function()
            Macro:SetTemplate("/tar $Target.Name$")
            Macro:ResetTemplate()
            assert.are.equal(ns.Template.DEFAULT_BODY, Macro:GetTemplate())
        end)
    end)

    describe("Rename", function()
        it("renames the macro in place", function()
            Macro:Bind({ name = "Boar" })
            assert.is_true(Macro:Rename("Hunt"))
            assert.are.equal("Hunt", Macro:GetName())
            assert.are.equal(1, #Wow.macros)
            assert.are.equal("Hunt", Wow.macros[1].name)
            assert.matches("Renamed the macro GirthBind %-> Hunt", Wow.ChatText())
        end)

        it("accepts a quoted name", function()
            assert.is_true(Macro:Rename('"My Macro"'))
            assert.are.equal("My Macro", Macro:GetName())
        end)

        it("saves the name for later when the macro doesn't exist yet", function()
            assert.is_true(Macro:Rename("Later"))
            assert.are.equal(0, #Wow.macros)
            Macro:Bind({ name = "Boar" })
            assert.are.equal("Later", Wow.macros[1].name)
        end)

        it("adopts an existing macro, overwriting its body and keeping its icon", function()
            Macro:Bind({ name = "Boar" })
            Wow.macros[2] = { name = "Hunt", icon = 555, body = "/cast Fireball" }
            assert.is_nil(Macro:ValidateName("Hunt"))
            assert.is_true(Macro:Rename("Hunt"))

            assert.are.equal("Hunt", Macro:GetName())
            assert.are.equal(2, #Wow.macros)
            assert.are.same({ name = "Hunt", icon = 555, body = "/targetexact Boar\n/cleartarget [dead]\n/tm 8" }, Wow.macros[2])
            -- The macro GirthBind managed before is left exactly as it was.
            assert.are.same({ name = "GirthBind", icon = Macro.ICON, body = "/targetexact Boar\n/cleartarget [dead]\n/tm 8" },
                Wow.macros[1])
            assert.matches("now manages your existing Hunt macro", Wow.ChatText())
            assert.matches("GirthBind is left as it was", Wow.ChatText())

            -- From then on, binds update the adopted macro only.
            Macro:Bind({ name = "Young Wolf" })
            assert.matches("Young Wolf", Wow.macros[2].body)
            assert.matches("Boar", Wow.macros[1].body)
        end)

        it("adopts an existing macro before GirthBind has made its own", function()
            Wow.macros[1] = { name = "Hunt", icon = 555, body = "/cast Fireball" }
            assert.is_true(Macro:Rename("Hunt"))
            assert.are.equal(1, #Wow.macros)
            assert.are.equal("/stopmacro", Wow.macros[1].body)
            assert.matches("now manages your existing Hunt macro", Wow.ChatText())
            assert.is_nil(Wow.ChatText():match("is left as it was"))
        end)

        it("can adopt the macro it managed before", function()
            Macro:Bind({ name = "Boar" })
            Wow.macros[2] = { name = "Hunt", icon = 1, body = "" }
            Macro:Rename("Hunt")
            Macro:Bind({ name = "Young Wolf" })
            assert.is_true(Macro:Rename("GirthBind"))
            assert.are.equal("GirthBind", Macro:GetName())
            assert.matches("Young Wolf", Wow.macros[1].body)
        end)

        it("refuses names that are empty, too long, or set in combat", function()
            Macro:Bind({ name = "Boar" })
            assert.matches("needs a name", Macro:ValidateName("  "))
            assert.matches("at most 16", Macro:ValidateName(string.rep("n", 17)))
            Wow.inCombat = true
            assert.matches("in combat", Macro:ValidateName("Other"))
            assert.is_false(Macro:Rename("Other"))
            assert.are.equal("GirthBind", Macro:GetName())
        end)

        it("treats renaming to the current name as a no-op", function()
            assert.is_nil(Macro:ValidateName("GirthBind"))
            assert.is_true(Macro:Rename("GirthBind"))
        end)
    end)

    describe("Pickup and EnsureExists", function()
        it("creates the idle macro and puts it on the cursor", function()
            assert.is_true(Macro:Pickup())
            assert.are.equal("/stopmacro", macro().body)
            assert.are.same({ macro = 1 }, Wow.cursor)
            assert.matches("does nothing yet", Wow.ChatText())
        end)

        it("refuses to pick up in combat", function()
            Wow.inCombat = true
            assert.is_false(Macro:Pickup())
            assert.is_nil(Wow.cursor)
        end)

        it("creates the idle macro once, silently afterwards", function()
            Macro:EnsureExists()
            assert.are.equal(1, #Wow.macros)
            local lines = #Wow.chat
            Macro:EnsureExists()
            assert.are.equal(1, #Wow.macros)
            assert.are.equal(lines, #Wow.chat)
        end)
    end)
end)
