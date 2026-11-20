-- UI/LookupWindow.lua
--
-- The quest lookup window (/gb, /gb lookup, /gb idlookup, and the menus' "Open in GirthBind…").
-- Left: a search box and quest list (your quest log until you type). Right: the selected
-- quest's objectives, each with the enemies that serve it and a Bind button per enemy.
--
-- Row data is built by pure functions (BuildQuestRows, BuildEnemyRows) so it can be tested;
-- the frame code only draws those rows.

---@type string, GirthBindNamespace
local _, ns = ...
local L, Log, Util = ns.L, ns.Log, ns.Util
local QuestData, QuestSearch, QuestLog = ns.QuestData, ns.QuestSearch, ns.QuestLog
local MESSAGES = ns.MESSAGES

---@class GirthBindLookup : AceModule, AceEvent-3.0
local Lookup = ns.addon:NewModule("Lookup", "AceEvent-3.0")
ns.Lookup = Lookup

Lookup.WIDTH, Lookup.HEIGHT = 780, 540
Lookup.LEFT_WIDTH = 310
Lookup.COLLAPSE_AT = 10 -- enemies shown per objective before "Show N more"
Lookup.SEARCH_DELAY = 0.15
Lookup.PORTRAIT = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local ROW_HEIGHT = { header = 22, quest = 34, group = 28, enemy = 34, more = 22, note = 24 }

local KIND_LABELS = {
    kill = "OBJECTIVE_KIND_KILL",
    killCredit = "OBJECTIVE_KIND_KILL_CREDIT",
    item = "OBJECTIVE_KIND_ITEM",
    special = "OBJECTIVE_KIND_SPECIAL",
}

local RANK_LABELS = { [1] = "RANK_ELITE", [2] = "RANK_RARE_ELITE", [3] = "RANK_BOSS", [4] = "RANK_RARE" }

local GRAY, WHITE, GOLD = Util.COLORS.GRAY, Util.COLORS.WHITE, Util.COLORS.GOLD

function Lookup:OnEnable()
    self.query = ""
    self.selectedQuestId = nil
    self.expanded = {}
    self:RegisterMessage(MESSAGES.BOUND_CHANGED, "OnStateChanged")
    self:RegisterMessage(MESSAGES.MACRO_CHANGED, "OnStateChanged")
end

--------------------------------------------------------------------------------------------
-- Row models (pure)
--------------------------------------------------------------------------------------------

---@class GirthBindLookupRow
---@field kind "header"|"quest"|"group"|"enemy"|"more"|"note"
---@field text string?
---@field id integer? Quest ID (quest rows)
---@field level integer?
---@field isComplete boolean?
---@field group GirthBindEnemyGroup?
---@field groupIndex integer?
---@field enemy GirthBindEnemy?
---@field isBound boolean?
---@field hidden integer? Enemies a "more" row reveals

--- Left list rows: the quest log for an empty query, else search results.
---@param query string
---@return GirthBindLookupRow[] rows
---@return string status One-line summary shown under the search box
function Lookup.BuildQuestRows(query)
    local rows = {}
    local trimmed = Util.Trim(query)
    local available, reason = QuestData.GetStatus()
    available = available == QuestData.STATUS.OK

    if trimmed == "" then
        local count = 0
        for _, entry in ipairs(QuestLog.GetEntries()) do
            if entry.kind == "header" then
                rows[#rows + 1] = { kind = "header", text = entry.name }
            else
                count = count + 1
                rows[#rows + 1] = {
                    kind = "quest",
                    id = entry.id,
                    text = entry.name,
                    level = entry.level,
                    isComplete = entry.isComplete,
                }
            end
        end
        if not available then
            return rows, reason
        end
        if count == 0 then
            return rows, L["WINDOW_STATUS_LOG_EMPTY"]
        end
        return rows, L["WINDOW_STATUS_LOG"]:format(count)
    end

    if not available then
        return rows, reason
    end
    if not QuestSearch.IsReady() then
        return rows, L["WINDOW_STATUS_INDEXING"]:format(math.floor(QuestSearch.GetProgress() * 100))
    end
    local results, total = QuestSearch.Search(trimmed)
    for _, entry in ipairs(results) do
        local quest = QuestData.GetQuest(entry.id)
        rows[#rows + 1] = { kind = "quest", id = entry.id, text = entry.name, level = quest and quest.level }
    end
    if total == 0 then
        return rows, L["WINDOW_STATUS_NO_MATCHES"]
    elseif total > #results then
        return rows, L["WINDOW_STATUS_TRUNCATED"]:format(#results, total)
    end
    return rows, L["WINDOW_STATUS_MATCHES"]:format(total)
end

--- Right list rows for a quest: a header per objective, its enemies (collapsed past
--- COLLAPSE_AT unless expanded), or a note when there's nothing to show.
---@param questId integer?
---@param expanded table<integer, boolean>? Objective indexes showing every enemy
---@return GirthBindLookupRow[]
function Lookup.BuildEnemyRows(questId, expanded)
    local rows = {}
    local status, reason = QuestData.GetStatus()
    if status ~= QuestData.STATUS.OK then
        rows[1] = { kind = "note", text = reason }
        return rows
    end
    if not questId then
        rows[1] = { kind = "note", text = L["WINDOW_PICK_QUEST"] }
        return rows
    end
    if not QuestData.GetQuest(questId) then
        rows[1] = { kind = "note", text = L["WINDOW_QUEST_UNKNOWN"]:format(questId) }
        return rows
    end
    local groups = QuestData.GetEnemyGroups(questId)
    if #groups == 0 then
        rows[1] = { kind = "note", text = L["WINDOW_NO_ENEMIES"] }
        return rows
    end

    local bound = ns.Macro:GetBound()
    for groupIndex, group in ipairs(groups) do
        rows[#rows + 1] = { kind = "group", group = group, groupIndex = groupIndex }
        local enemies = group.enemies
        if #enemies == 0 then
            rows[#rows + 1] = { kind = "note", text = L["WINDOW_GROUP_NO_ENEMIES"] }
        else
            local limit = (expanded and expanded[groupIndex]) and #enemies or Lookup.COLLAPSE_AT
            for position = 1, math.min(limit, #enemies) do
                local enemy = enemies[position]
                rows[#rows + 1] = {
                    kind = "enemy",
                    enemy = enemy,
                    isBound = bound ~= nil and bound.name == enemy.name,
                }
            end
            if #enemies > limit then
                rows[#rows + 1] = { kind = "more", groupIndex = groupIndex, hidden = #enemies - limit }
            end
        end
    end
    return rows
end

--- "Level 5-7 · Elite · Elwynn Forest"
---@param enemy GirthBindEnemy
---@return string
function Lookup.DescribeEnemy(enemy)
    local parts = {}
    local levels = Util.FormatLevelRange(enemy.minLevel, enemy.maxLevel)
    if levels then
        parts[#parts + 1] = L["WINDOW_LEVEL"]:format(levels)
    end
    if RANK_LABELS[enemy.rank or 0] then
        parts[#parts + 1] = L[RANK_LABELS[enemy.rank]]
    end
    local zone = Util.GetAreaName(enemy.zoneId)
    if zone then
        parts[#parts + 1] = zone
    end
    return table.concat(parts, " · ")
end

--- "Level 12 (requires 10) · Elwynn Forest · Quest 123 · In your quest log"
---@param quest GirthBindQuestInfo
---@return string
function Lookup.DescribeQuest(quest)
    local parts = {}
    if quest.level and quest.level > 0 then
        if quest.requiredLevel and quest.requiredLevel > 0 and quest.requiredLevel ~= quest.level then
            parts[#parts + 1] = L["WINDOW_QUEST_LEVEL_REQ"]:format(quest.level, quest.requiredLevel)
        else
            parts[#parts + 1] = L["WINDOW_LEVEL"]:format(quest.level)
        end
    end
    if quest.zoneName then
        parts[#parts + 1] = quest.zoneName
    end
    parts[#parts + 1] = L["WINDOW_QUEST_ID"]:format(quest.id)
    if QuestLog.IsOnQuest(quest.id) then
        parts[#parts + 1] = L["WINDOW_IN_LOG"]
    end
    return table.concat(parts, " · ")
end

--------------------------------------------------------------------------------------------
-- Opening
--------------------------------------------------------------------------------------------

---@class GirthBindLookupOpenOptions
---@field questId integer? Select this quest
---@field query string? Search for this text
---@field exact boolean? With query: open the quest directly when exactly one name matches

--- Shows the window. With no options it shows your quest log.
---@param options GirthBindLookupOpenOptions?
function Lookup:Open(options)
    options = options or {}
    local frame = self:GetFrame()
    frame:Show()
    frame:Raise()
    self.pendingExact = nil

    if options.questId then
        self:SetQuery("")
        self:SelectQuest(options.questId)
    elseif options.query and Util.Trim(options.query) ~= "" then
        self.pendingExact = options.exact and Util.Trim(options.query) or nil
        self:SetQuery(options.query)
    else
        self:SetQuery("")
    end
    self:EnsureIndex()
    self:ResolvePendingExact()
end

function Lookup:Close()
    if self.frame then
        self.frame:Hide()
    end
end

---@return boolean
function Lookup:IsShown()
    return self.frame ~= nil and self.frame:IsShown()
end

--- Starts building the quest name index (once), refreshing the list as it progresses.
function Lookup:EnsureIndex()
    if QuestSearch.IsReady() or not QuestData.IsAvailable() then
        return
    end
    QuestSearch.Build(function()
        self:RefreshQuestList(false)
        self:ResolvePendingExact()
    end, function()
        if Util.Trim(self.query) ~= "" then
            self:RefreshQuestList(false)
        end
    end)
end

-- `/gb lookup <name>`: one case-insensitive exact match opens that quest.
function Lookup:ResolvePendingExact()
    if not self.pendingExact or not QuestSearch.IsReady() then
        return
    end
    local ids = QuestSearch.FindExact(self.pendingExact)
    self.pendingExact = nil
    if #ids == 1 then
        self:SelectQuest(ids[1])
    end
    Log.Debug("Exact lookup matched %d quest(s)", #ids)
end

---@param query string
function Lookup:SetQuery(query)
    -- A search still waiting on its typing delay must not overwrite this one.
    if self.searchTimer then
        self.searchTimer:Cancel()
        self.searchTimer = nil
    end
    self.query = query or ""
    if self.searchBox and self.searchBox:GetText() ~= self.query then
        self.searchBox:SetText(self.query)
    end
    self:RefreshQuestList(false)
end

---@param questId integer
function Lookup:SelectQuest(questId)
    local changed = self.selectedQuestId ~= questId
    if changed then
        self.expanded = {}
    end
    self.selectedQuestId = questId
    self:RefreshQuestList(true)
    self:RefreshQuestDetail(not changed)
end

function Lookup:OnStateChanged()
    if self:IsShown() then
        self:RefreshQuestDetail(true)
        self:RefreshFooter()
    end
end

function Lookup:QUEST_LOG_UPDATE()
    if Util.Trim(self.query) ~= "" or self.logRefreshQueued then
        return
    end
    self.logRefreshQueued = true
    C_Timer.After(0.2, function()
        self.logRefreshQueued = false
        if self:IsShown() and Util.Trim(self.query) == "" then
            self:RefreshQuestList(true)
        end
    end)
end

--------------------------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------------------------

local function SetRowText(fontString, text, color)
    fontString:SetText(color and Util.Color(color, text or "") or (text or ""))
end

local function QuestTitleColor(row)
    if row.isComplete then
        return Util.COLORS.GREEN
    end
    local GetQuestDifficultyColor = _G.GetQuestDifficultyColor
    if row.level and row.level > 0 and GetQuestDifficultyColor then
        local color = GetQuestDifficultyColor(row.level)
        if color and color.r then
            local function byte(value)
                return math.floor(value * 255 + 0.5)
            end
            return ("ff%02x%02x%02x"):format(byte(color.r), byte(color.g), byte(color.b))
        end
    end
    return GOLD
end

-- Every list row is a pooled Button; its parts are made once and shown per row kind.
local function EnsureRowParts(row)
    if row.parts then
        return row.parts
    end
    local parts = {}
    parts.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    parts.highlight:SetAllPoints()
    parts.highlight:SetColorTexture(1, 1, 1, 0.08)
    parts.selected = row:CreateTexture(nil, "BACKGROUND")
    parts.selected:SetAllPoints()
    parts.selected:SetColorTexture(1, 0.82, 0, 0.14)
    parts.title = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    parts.title:SetJustifyH("LEFT")
    parts.title:SetWordWrap(false)
    parts.sub = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    parts.sub:SetJustifyH("LEFT")
    parts.sub:SetWordWrap(false)
    parts.bind = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    parts.bind:SetSize(70, 22)
    parts.bind:SetPoint("RIGHT", -6, 0)
    row.parts = parts
    return parts
end

local function LayoutRow(row, parts, twoLines, rightInset)
    parts.title:ClearAllPoints()
    parts.sub:ClearAllPoints()
    if twoLines then
        parts.title:SetPoint("TOPLEFT", 8, -4)
        parts.title:SetPoint("RIGHT", row, "RIGHT", -rightInset, 0)
        parts.sub:SetPoint("TOPLEFT", parts.title, "BOTTOMLEFT", 0, -2)
        parts.sub:SetPoint("RIGHT", row, "RIGHT", -rightInset, 0)
        parts.sub:Show()
    else
        parts.title:SetPoint("LEFT", 8, 0)
        parts.title:SetPoint("RIGHT", row, "RIGHT", -rightInset, 0)
        parts.sub:Hide()
    end
end

function Lookup:InitQuestRow(row, data)
    local parts = EnsureRowParts(row)
    parts.bind:Hide()
    parts.selected:Hide()
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)

    if data.kind == "header" then
        row:EnableMouse(false)
        LayoutRow(row, parts, false, 8)
        parts.title:SetFontObject("GameFontNormalSmall")
        SetRowText(parts.title, data.text, WHITE)
        row:SetScript("OnClick", nil)
        return
    end

    row:EnableMouse(true)
    LayoutRow(row, parts, true, 8)
    parts.title:SetFontObject("GameFontNormal")
    local title = data.text
    if data.level and data.level > 0 then
        title = ("[%d] %s"):format(data.level, title)
    end
    if data.isComplete then
        title = title .. " " .. L["WINDOW_COMPLETE_SUFFIX"]
    end
    SetRowText(parts.title, title, QuestTitleColor(data))
    local quest = QuestData.GetQuest(data.id)
    local sub = { L["WINDOW_QUEST_ID"]:format(data.id) }
    if quest and quest.zoneName then
        table.insert(sub, 1, quest.zoneName)
    end
    SetRowText(parts.sub, table.concat(sub, " · "), GRAY)
    parts.selected:SetShown(data.id == self.selectedQuestId)
    row:SetScript("OnClick", function()
        self:SelectQuest(data.id)
    end)
end

local function ShowEnemyTooltip(row, enemy)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(enemy.name, 1, 1, 1)
    local description = Lookup.DescribeEnemy(enemy)
    if description ~= "" then
        GameTooltip:AddLine(description, 0.8, 0.8, 0.8, true)
    end
    local ids = {}
    for index, npcId in ipairs(enemy.npcIds) do
        ids[index] = tostring(npcId)
    end
    GameTooltip:AddLine(L["WINDOW_TOOLTIP_NPC_IDS"]:format(table.concat(ids, ", ")), 0.6, 0.6, 0.6, true)
    if enemy.inQuestZone then
        GameTooltip:AddLine(L["WINDOW_TOOLTIP_IN_ZONE"], 0.4, 0.9, 0.4, true)
    end
    GameTooltip:Show()
end

function Lookup:InitDetailRow(row, data)
    local parts = EnsureRowParts(row)
    parts.bind:Hide()
    parts.selected:Hide()
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row:EnableMouse(false)

    if data.kind == "group" then
        local group = data.group
        LayoutRow(row, parts, false, 8)
        parts.title:SetFontObject("GameFontNormal")
        local label = group.label
        if group.count and group.count > 1 then
            label = L["WINDOW_GROUP_COUNT"]:format(label, group.count)
        end
        SetRowText(parts.title, label .. "  " .. Util.Color(GRAY, L[KIND_LABELS[group.kind]]), GOLD)
    elseif data.kind == "enemy" then
        local enemy = data.enemy
        row:EnableMouse(true)
        LayoutRow(row, parts, true, 84)
        parts.title:SetFontObject("GameFontHighlight")
        SetRowText(parts.title, enemy.name, WHITE)
        SetRowText(parts.sub, Lookup.DescribeEnemy(enemy), GRAY)
        parts.selected:SetShown(data.isBound)
        parts.bind:Show()
        parts.bind:SetText(data.isBound and L["WINDOW_BOUND_BUTTON"] or L["WINDOW_BIND_BUTTON"])
        parts.bind:SetEnabled(not data.isBound)
        parts.bind:SetScript("OnClick", function()
            ns.Macro:Bind({ name = enemy.name, npcId = enemy.npcId })
        end)
        row:SetScript("OnEnter", function()
            ShowEnemyTooltip(row, enemy)
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    elseif data.kind == "more" then
        row:EnableMouse(true)
        LayoutRow(row, parts, false, 8)
        parts.title:SetFontObject("GameFontHighlightSmall")
        SetRowText(parts.title, L["WINDOW_SHOW_MORE"]:format(data.hidden), "ff66bbff")
        row:SetScript("OnClick", function()
            self.expanded[data.groupIndex] = true
            self:RefreshQuestDetail(true)
        end)
    else -- note
        LayoutRow(row, parts, false, 8)
        parts.title:SetFontObject("GameFontDisableSmall")
        SetRowText(parts.title, data.text)
    end
end

local function CreateList(parent, initializer)
    local scrollBox = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local scrollBar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 4, 0)
    scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 4, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, data)
        return ROW_HEIGHT[data.kind] or 24
    end)
    view:SetElementFactory(function(factory)
        factory("Button", initializer)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
    return scrollBox
end

-- SetDataProvider's second argument is ScrollBoxConstants.RetainScrollPosition (true) to keep
-- the scroll position, as other Forever addons pass it.
local function SetRows(scrollBox, rows, keepPosition)
    scrollBox:SetDataProvider(CreateDataProvider(rows), keepPosition and true or false)
end

---@return Frame
function Lookup:GetFrame()
    if self.frame then
        return self.frame
    end
    local frameName = ns.SV_NAME:gsub("DB$", "") .. "LookupFrame"
    local frame = CreateFrame("Frame", frameName, UIParent, "PortraitFrameTemplate")
    -- New frames start shown; hide it so Open's Show() fires OnShow the first time too.
    frame:Hide()
    self.frame = frame
    table.insert(UISpecialFrames, frameName)

    frame:SetSize(Lookup.WIDTH, Lookup.HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(window)
        window:StopMovingOrSizing()
        self:SavePosition()
    end)
    frame:HookScript("OnShow", function()
        self:RegisterEvent("QUEST_LOG_UPDATE")
        self:RefreshFooter()
    end)
    frame:HookScript("OnHide", function()
        self:UnregisterEvent("QUEST_LOG_UPDATE")
    end)
    frame:SetTitle(L["WINDOW_TITLE"])
    if frame.GetPortrait and frame:GetPortrait() then
        frame:GetPortrait():SetTexture(Lookup.PORTRAIT)
    end
    self:RestorePosition()

    local hint = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", 66, -36)
    hint:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["WINDOW_HINT"])

    -- Left: search and quest list
    local leftInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    leftInset:SetPoint("TOPLEFT", 10, -62)
    leftInset:SetPoint("BOTTOMLEFT", 10, 30)
    leftInset:SetWidth(Lookup.LEFT_WIDTH)

    local searchBox = CreateFrame("EditBox", nil, leftInset, "SearchBoxTemplate")
    searchBox:SetPoint("TOPLEFT", 12, -8)
    searchBox:SetPoint("RIGHT", leftInset, "RIGHT", -8, 0)
    searchBox:SetHeight(20)
    searchBox:SetAutoFocus(false)
    searchBox:HookScript("OnTextChanged", function(box)
        self:OnSearchTextChanged(box:GetText())
    end)
    searchBox:HookScript("OnEnterPressed", function(box)
        box:ClearFocus()
        self:ApplySearch(box:GetText())
    end)
    self.searchBox = searchBox

    local status = leftInset:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", 10, -34)
    status:SetPoint("RIGHT", leftInset, "RIGHT", -8, 0)
    status:SetJustifyH("LEFT")
    self.statusText = status

    local questList = CreateList(leftInset, function(row, data)
        self:InitQuestRow(row, data)
    end)
    questList:SetPoint("TOPLEFT", 4, -52)
    questList:SetPoint("BOTTOMRIGHT", -18, 4)
    self.questList = questList

    -- Right: selected quest
    local rightInset = CreateFrame("Frame", nil, frame, "InsetFrameTemplate")
    rightInset:SetPoint("TOPLEFT", leftInset, "TOPRIGHT", 6, 0)
    rightInset:SetPoint("BOTTOMRIGHT", -10, 30)

    local questTitle = rightInset:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    questTitle:SetPoint("TOPLEFT", 12, -10)
    questTitle:SetPoint("RIGHT", rightInset, "RIGHT", -12, 0)
    questTitle:SetJustifyH("LEFT")
    questTitle:SetWordWrap(false)
    self.questTitle = questTitle

    local questMeta = rightInset:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    questMeta:SetPoint("TOPLEFT", questTitle, "BOTTOMLEFT", 0, -4)
    questMeta:SetPoint("RIGHT", rightInset, "RIGHT", -12, 0)
    questMeta:SetJustifyH("LEFT")
    questMeta:SetWordWrap(false)
    self.questMeta = questMeta

    local detailList = CreateList(rightInset, function(row, data)
        self:InitDetailRow(row, data)
    end)
    detailList:SetPoint("TOPLEFT", 4, -52)
    detailList:SetPoint("BOTTOMRIGHT", -18, 4)
    self.detailList = detailList

    -- Footer: what the macro does now
    local footer = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", 16, 10)
    footer:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    footer:SetJustifyH("LEFT")
    self.footerText = footer

    self:RefreshQuestList(false)
    self:RefreshQuestDetail(false)
    return frame
end

function Lookup:OnSearchTextChanged(text)
    if text == self.query then
        return
    end
    if self.searchTimer then
        self.searchTimer:Cancel()
    end
    self.searchTimer = C_Timer.NewTimer(Lookup.SEARCH_DELAY, function()
        self.searchTimer = nil
        self:ApplySearch(text)
    end)
end

function Lookup:ApplySearch(text)
    if self.searchTimer then
        self.searchTimer:Cancel()
        self.searchTimer = nil
    end
    self.query = text or ""
    self:EnsureIndex()
    self:RefreshQuestList(false)
end

---@param keepPosition boolean? Keep the scroll position (same list, new state)
function Lookup:RefreshQuestList(keepPosition)
    if not self.questList then
        return
    end
    local rows, status = Lookup.BuildQuestRows(self.query)
    self.statusText:SetText(status or "")
    SetRows(self.questList, rows, keepPosition)
end

---@param keepPosition boolean? Keep the scroll position (same quest, new state)
function Lookup:RefreshQuestDetail(keepPosition)
    if not self.detailList then
        return
    end
    local questId = self.selectedQuestId
    local quest = questId and QuestData.GetQuest(questId)
    if quest then
        self.questTitle:SetText(quest.name)
        self.questMeta:SetText(Lookup.DescribeQuest(quest))
    elseif questId and QuestData.IsAvailable() then
        self.questTitle:SetText(L["WINDOW_QUEST_UNKNOWN_TITLE"])
        self.questMeta:SetText(L["WINDOW_QUEST_ID"]:format(questId))
    else
        self.questTitle:SetText(L["WINDOW_TITLE"])
        self.questMeta:SetText("")
    end
    SetRows(self.detailList, Lookup.BuildEnemyRows(questId, self.expanded), keepPosition)
end

function Lookup:RefreshFooter()
    if not self.footerText then
        return
    end
    local macroName = Util.Color(GOLD, ns.Macro:GetName())
    local bound = ns.Macro:GetBound()
    if bound then
        self.footerText:SetText(L["WINDOW_FOOTER_BOUND"]:format(macroName, Util.Color(WHITE, bound.name)))
    else
        self.footerText:SetText(L["WINDOW_FOOTER_IDLE"]:format(macroName))
    end
end

function Lookup:SavePosition()
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    if point then
        ns.db.global.window = { point = point, relativePoint = relativePoint, x = x, y = y }
    end
end

function Lookup:RestorePosition()
    local saved = ns.db.global.window
    self.frame:ClearAllPoints()
    self.frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
end
