local Loader = require("loader")
local FakeQuestieDB = require("questiedb")

describe("Quest menus", function()
    local ns, Wow, opened

    local function load(options)
        options = options or {}
        if options.questieDB == nil and not options.noDB then
            options.questieDB = FakeQuestieDB.Sample()
        end
        ns, Wow = Loader.Load(options)
        opened = {}
        ns.Lookup.Open = function(_, openOptions)
            opened[#opened + 1] = openOptions
        end
    end

    local function texts(items)
        local list = {}
        for index, item in ipairs(items) do
            list[index] = item.text
        end
        return list
    end

    describe("MenuModel", function()
        it("is disabled with QuestieDB's reason when QuestieDB is missing", function()
            load({ noDB = true })
            local model = ns.MenuModel.Build(7)
            assert.is_false(model.enabled)
            assert.matches("QuestieDB", model.reason)
            assert.are.same({}, model.items)
        end)

        it("is disabled for unknown quests and quests without enemies", function()
            load()
            assert.matches("doesn't know this quest", ns.MenuModel.Build(424242).reason)
            assert.matches("no enemies", ns.MenuModel.Build(46).reason)
            assert.is_false(ns.MenuModel.Build(nil).enabled)
        end)

        it("offers Open first, then one Bind item per enemy", function()
            load()
            local model = ns.MenuModel.Build(47)
            assert.is_true(model.enabled)
            assert.are.same({
                "Open in GirthBind...",
                "Kobold Worker", "Kobold Tunneler", "Kobold Geomancer", "Defias Bandit", "Defias Knuckleduster",
            }, texts(model.items))

            model.items[1].action()
            assert.are.same({ { questId = 47 } }, opened)

            model.items[5].action()
            assert.are.same({ name = "Defias Bandit", npcId = 116 }, ns.Macro:GetBound())
            assert.are.equal("Defias Bandit (bound)", ns.MenuModel.Build(47).items[5].text)
        end)

        it("caps the enemy list and points to the window for the rest", function()
            load()
            ns.MenuModel.MAX_ENEMIES = 2
            local model = ns.MenuModel.Build(47)
            assert.are.same({ "Open in GirthBind...", "Kobold Worker", "Kobold Tunneler", "3 more in the GirthBind window..." },
                texts(model.items))
            model.items[4].action()
            assert.are.same({ { questId = 47 } }, opened)
        end)
    end)

    describe("Questie tracker", function()
        local trackerMenu

        local function loadWithQuestie(getMenu)
            trackerMenu = {
                GetMenuForQuest = getMenu or function()
                    return { { text = "Quest title", isTitle = true }, { text = "Untrack" }, { text = "Cancel" } }
                end,
            }
            load({
                addons = { Questie = { loaded = true, enabled = true } },
                before = function()
                    _G.QuestieLoader = {
                        ImportModule = function(_, name)
                            return name == "TrackerMenu" and trackerMenu or nil
                        end,
                    }
                end,
            })
        end

        it("adds the submenu just above Cancel", function()
            loadWithQuestie()
            local menu = trackerMenu:GetMenuForQuest({ Id = 7 })
            assert.are.equal(4, #menu)
            assert.are.equal("Cancel", menu[4].text)
            local entry = menu[3]
            assert.matches("GirthBind", entry.text)
            assert.is_true(entry.hasArrow)
            assert.are.same({ "Open in GirthBind...", "Kobold Vermin" }, texts(entry.menuList))
            entry.menuList[2].func()
            assert.are.equal("Kobold Vermin", ns.Macro:GetBound().name)
        end)

        it("greys the entry out with a tooltip when there's nothing to bind", function()
            loadWithQuestie()
            local entry = trackerMenu:GetMenuForQuest({ Id = 46 })[3]
            assert.is_true(entry.disabled)
            assert.is_false(entry.hasArrow)
            assert.matches("no enemies", entry.tooltipText)
            assert.is_true(entry.tooltipWhileDisabled)
        end)

        it("hooks once and always returns Questie's menu, even when GirthBind fails", function()
            loadWithQuestie()
            ns.QuestieMenu:OnEnable() -- a second enable must not wrap again
            ns.MenuModel.Build = function()
                error("boom")
            end
            local menu = trackerMenu:GetMenuForQuest({ Id = 7 })
            assert.are.equal(3, #menu)
            assert.are.equal(1, #Wow.errors)
            assert.matches("boom", Wow.errors[1])
        end)

        it("leaves non-table menus and quests without an ID alone", function()
            loadWithQuestie(function()
                return nil
            end)
            assert.is_nil(trackerMenu:GetMenuForQuest({ Id = 7 }))
            loadWithQuestie()
            assert.are.equal(3, #trackerMenu:GetMenuForQuest({}))
        end)

        it("does nothing when Questie isn't loaded", function()
            load()
            assert.are.same({}, Wow.errors)
        end)
    end)

    describe("Blizzard menus", function()
        local function NewRoot()
            local root = { children = {}, dividers = 0 }
            function root:CreateDivider()
                self.dividers = self.dividers + 1
            end
            function root:CreateButton(text, callback)
                local child = NewRoot()
                child.text, child.callback, child.enabled = text, callback, true
                function child:SetEnabled(enabled)
                    self.enabled = enabled
                end
                function child:SetTooltip(fn)
                    self.tooltip = fn
                end
                self.children[#self.children + 1] = child
                return child
            end
            return root
        end

        it("adds the submenu to the quest log title menu", function()
            load()
            local root = NewRoot()
            Wow.menuCallbacks.MENU_QUEST_MAP_LOG_TITLE({ questID = 7 }, root)
            assert.are.equal(1, root.dividers)
            local entry = root.children[1]
            assert.matches("GirthBind", entry.text)
            assert.are.same({ "Open in GirthBind...", "Kobold Vermin" }, texts(entry.children))
            entry.children[1].callback()
            assert.are.same({ { questId = 7 } }, opened)
        end)

        it("decorates each menu description only once", function()
            load()
            local root = NewRoot()
            Wow.menuCallbacks.MENU_QUEST_MAP_LOG_TITLE({ questID = 7 }, root)
            Wow.menuCallbacks.MENU_QUEST_MAP_LOG_TITLE({ questID = 7 }, root)
            assert.are.equal(1, #root.children)
        end)

        it("uses the hovered tracker header's quest, only while the cursor is on it", function()
            load()
            local header = CreateFrame("Button")
            EventRegistry:TriggerEvent("OnQuestBlockHeader.OnEnter", { id = 33, HeaderButton = header })

            local root = NewRoot()
            Wow.menuCallbacks.MENU_QUEST_OBJECTIVE_TRACKER(nil, root)
            assert.are.equal(0, #root.children)

            header._mouseOver = true
            Wow.menuCallbacks.MENU_QUEST_OBJECTIVE_TRACKER(nil, root)
            assert.are.equal(1, #root.children)
            assert.are.equal("Young Wolf", root.children[1].children[2].text)
        end)

        it("greys out the entry when the quest has nothing to bind", function()
            load()
            local root = NewRoot()
            Wow.menuCallbacks.MENU_QUEST_MAP_LOG_TITLE({ questID = 46 }, root)
            local entry = root.children[1]
            assert.is_false(entry.enabled)
            assert.is_function(entry.tooltip)
            assert.are.same({}, entry.children)
        end)

        it("ignores owners without a usable quest ID", function()
            load()
            local root = NewRoot()
            Wow.menuCallbacks.MENU_QUEST_MAP_LOG_TITLE({}, root)
            Wow.menuCallbacks.MENU_QUEST_MAP_LOG_TITLE({ questID = 1.5 }, root)
            assert.are.equal(0, #root.children)
        end)
    end)

    describe("EllesmereUI custom tracker", function()
        local shown

        local function loadWithEllesmere()
            shown = {}
            load({
                before = function()
                    _G.EllesmereUI = {
                        ShowContextMenu = function(anchor, items, opts)
                            shown[#shown + 1] = { anchor = anchor, items = items, opts = opts }
                        end,
                    }
                end,
            })
            Wow.questLog = { { questID = 7, title = "Kobold Camp Cleanup" } }
        end

        it("appends a divider and the submenu to quest row menus", function()
            loadWithEllesmere()
            local items = { { text = "Kobold Camp Cleanup" }, { text = "Untrack" } }
            EllesmereUI.ShowContextMenu({ kind = "quest", id = 7 }, items, { fontKey = "questTracker" })
            local call = shown[1]
            assert.are.equal(2, #items) -- the caller's list isn't modified
            assert.are.equal(4, #call.items)
            assert.are.equal("---", call.items[3])
            local entry = call.items[4]
            assert.matches("GirthBind", entry.text)
            assert.are.same({ "Open in GirthBind...", "Kobold Vermin" }, texts(entry.children))
            assert.are.same({ fontKey = "questTracker" }, call.opts)
        end)

        it("passes every other EllesmereUI menu through untouched", function()
            loadWithEllesmere()
            local items = { { text = "Something else" } }
            EllesmereUI.ShowContextMenu({ kind = "zone", id = 7 }, items)
            EllesmereUI.ShowContextMenu({ kind = "quest", id = 7 }, items) -- title doesn't match
            EllesmereUI.ShowContextMenu(nil, items)
            assert.are.equal(items, shown[1].items)
            assert.are.equal(items, shown[2].items)
            assert.are.equal(items, shown[3].items)
        end)

        it("greys out the entry with a tooltip when there's nothing to bind", function()
            loadWithEllesmere()
            Wow.questLog = { { questID = 46, title = "Bounty on Murlocs" } }
            EllesmereUI.ShowContextMenu({ kind = "quest", id = 46 }, { { text = "Bounty on Murlocs" } })
            local entry = shown[1].items[3]
            assert.is_true(entry.isDisabled())
            assert.is_nil(entry.children)
            assert.matches("no enemies", entry.tooltip)
        end)
    end)
end)
