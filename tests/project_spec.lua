-- Repository-level checks: the TOC, embeds.xml and locale stay consistent with the code.

local Loader = require("loader")

local function read(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function exists(path)
    local file = io.open(path, "rb")
    if file then
        file:close()
        return true
    end
    return false
end

describe("Project", function()
    it("lists only files that exist in the TOC", function()
        for _, path in ipairs(Loader.TocFiles()) do
            assert.is_true(exists(path), path)
        end
        assert.is_true(exists("embeds.xml"))
    end)

    it("targets WoW Forever and declares its CurseForge project", function()
        local toc = read("GirthBind.toc")
        assert.matches("## Interface: 16001", toc, 1, true)
        assert.matches("## SavedVariables: GirthBindDB", toc, 1, true)
        assert.matches("## X%-Curse%-Project%-ID: 1815823", toc)
        assert.matches("## OptionalDeps: QuestieDB", toc, 1, true)
        assert.matches("## Version: @project-version@", toc, 1, true)
    end)

    it("embeds only libraries that are vendored", function()
        for path in read("embeds.xml"):gmatch('file="([^"]+)"') do
            assert.is_true(exists((path:gsub("\\", "/"))), path)
        end
    end)

    it("defines every locale key the source uses", function()
        local defined = {}
        for key in read("locales/enUS.lua"):gmatch('L%["([%w_]+)"%]%s*=') do
            defined[key] = true
        end
        local used = 0
        for _, path in ipairs(Loader.TocFiles()) do
            if path:match("^src/") then
                for key in read(path):gmatch('L%["([A-Z0-9_]+)"%]') do
                    used = used + 1
                    assert.is_true(defined[key], ("%s uses undefined locale key %s"):format(path, key))
                end
            end
        end
        assert.is_true(used > 50)
    end)
end)
