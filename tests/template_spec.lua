local Loader = require("loader")

describe("Template", function()
    local Template

    before_each(function()
        local ns = Loader.Load({ login = false })
        Template = ns.Template
    end)

    local function render(text, name)
        return Template.Render(text, Template.BuildContext(name and { name = name } or nil))
    end

    it("replaces $Target.Name$ with the bound enemy", function()
        local body, unknown = render("/targetexact $Target.Name$", "Kobold Vermin")
        assert.are.equal("/targetexact Kobold Vermin", body)
        assert.are.same({}, unknown)
    end)

    it("renders the default body", function()
        local body = render(Template.DEFAULT_BODY, "Young Wolf")
        assert.are.equal("/targetexact Young Wolf\n/cleartarget [dead]\n/tm 8", body)
    end)

    it("replaces every occurrence", function()
        assert.are.equal("/tar A\n/say A", (render("/tar $Target.Name$\n/say $Target.Name$", "A")))
    end)

    it("expands a known token with no value to an empty string", function()
        assert.are.equal("/targetexact ", (render("/targetexact $Target.Name$", nil)))
    end)

    it("is case-sensitive and leaves unknown tokens exactly as typed", function()
        local body, unknown = render("/tar $target.name$ $Target.Nmae$ $Target.Name$", "Boar")
        assert.are.equal("/tar $target.name$ $Target.Nmae$ Boar", body)
        assert.are.same({ "$target.name$", "$Target.Nmae$" }, unknown)
    end)

    it("treats $$ as a literal dollar sign", function()
        assert.are.equal("/say $5 for Boar", (render("/say $$5 for $Target.Name$", "Boar")))
        assert.are.equal("$Target.Name$", (render("$$Target.Name$$", "Boar")))
    end)

    it("keeps a lone or unterminated $ literal", function()
        assert.are.equal("/say $ and $Target.Name", (render("/say $ and $Target.Name", "Boar")))
    end)

    it("flags token-shaped text without a dot as unknown", function()
        local _, unknown = render("$Target$ $Target.Name.Extra$", "Boar")
        assert.are.same({ "$Target$", "$Target.Name.Extra$" }, unknown)
    end)

    it("reports each unknown token once, in order", function()
        assert.are.same({ "$A.b$", "$C.d$" }, Template.FindUnknown("$A.b$ $C.d$ $A.b$ $Target.Name$"))
    end)

    it("renders sample values for previews", function()
        assert.are.equal("/targetexact Kobold Vermin", (Template.Render("/targetexact $Target.Name$", nil, true)))
    end)

    it("parses into text, token and unknown parts", function()
        assert.are.same({
            { kind = "text", value = "/tar " },
            { kind = "token", value = "Target.Name" },
            { kind = "text", value = " " },
            { kind = "unknown", value = "$Foo.Bar$" },
        }, Template.Parse("/tar $Target.Name$ $Foo.Bar$"))
    end)

    it("lists built-in tokens and accepts new ones", function()
        local keys = {}
        for _, token in ipairs(Template.GetTokens()) do
            keys[#keys + 1] = token.key
        end
        assert.are.same({ "Target.Name" }, keys)

        Template.RegisterToken("Target.NpcId", {
            description = "npc id",
            sample = "6",
            resolve = function(context)
                return context.target and context.target.npcId
            end,
        })
        assert.is_true(Template.IsToken("Target.NpcId"))
        assert.are.equal("/say 6", (Template.Render("/say $Target.NpcId$", { target = { name = "x", npcId = 6 } })))
    end)

    it("rejects malformed token keys", function()
        assert.has_error(function()
            Template.RegisterToken("NoDot", { resolve = function() end })
        end)
        assert.has_error(function()
            Template.RegisterToken("Target.Name", {})
        end)
    end)
end)
