-- Macro/Macro.lua
--
-- Owns the one account macro GirthBind manages. Targeting and raid marks are protected actions,
-- so only a key press or click can do them: the macro does the work, and this module keeps its
-- body in sync with the bound enemy and the body template.
--
-- Macro edits are blocked in combat; they queue and apply when combat ends.

---@type string, GirthBindNamespace
local _, ns = ...
local L, Log, Util, Template, Database = ns.L, ns.Log, ns.Util, ns.Template, ns.Database
local MESSAGES = ns.MESSAGES

---@class GirthBindMacro : AceModule, AceEvent-3.0
local Macro = ns.addon:NewModule("Macro", "AceEvent-3.0")
ns.Macro = Macro

Macro.MAX_BODY = 255 -- bytes; the client refuses longer bodies
Macro.ICON = 134400 -- question mark; change it in /macro and GirthBind keeps yours
Macro.FALLBACK_MAX_ACCOUNT_MACROS = 120

---@enum GirthBindSyncResult
Macro.RESULT = {
    CREATED = "created",
    UPDATED = "updated",
    UNCHANGED = "unchanged",
    QUEUED = "queued", -- in combat; applies at PLAYER_REGEN_ENABLED
    MISSING = "missing", -- no macro and creating one wasn't allowed
    ERROR = "error",
}
local RESULT = Macro.RESULT

local GOLD, WHITE = Util.COLORS.GOLD, Util.COLORS.WHITE

---@return GirthBindGlobalSettings
local function Settings()
    return ns.db.global
end

function Macro:OnEnable()
    self.pending = nil
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

-- Catch up on anything that changed while the macro couldn't be written. Never creates: at
-- login the macro list may not be loaded yet, and creating then would make a duplicate.
function Macro:PLAYER_ENTERING_WORLD()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:Sync(false)
end

function Macro:PLAYER_REGEN_ENABLED()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local pending = self.pending
    self.pending = nil
    if pending then
        Log.Info("Combat ended; applying queued macro update")
        local result, err = self:Sync(pending.allowCreate)
        if pending.report then
            self:Report(result, err)
        end
    end
end

--------------------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------------------

---@return string
function Macro:GetName()
    return Settings().macro.name
end

---@return string
function Macro:GetTemplate()
    return Settings().macro.body
end

---@return GirthBindBound?
function Macro:GetBound()
    return Settings().bound
end

---@return boolean exists
---@return integer? index
function Macro:Exists()
    local index = GetMacroIndexByName(self:GetName())
    if index and index > 0 then
        return true, index
    end
    return false, nil
end

--- The body the macro would have for a bound enemy and template.
---@param bound GirthBindBound?
---@param template string
---@return string body
---@return string[] unknown
function Macro:RenderFor(bound, template)
    if not bound then
        return Template.IDLE_BODY, {}
    end
    return Template.Render(template, Template.BuildContext(bound))
end

---@return string body
---@return string[] unknown
function Macro:CurrentBody()
    return self:RenderFor(self:GetBound(), self:GetTemplate())
end

--- "targets Kobold Vermin" / "does nothing yet (nothing is bound)".
---@return string
function Macro:Describe()
    local bound = self:GetBound()
    if bound then
        return L["MACRO_DESCRIBE_TARGETS"]:format(Util.Color(WHITE, bound.name))
    end
    return L["MACRO_DESCRIBE_IDLE"]
end

--------------------------------------------------------------------------------------------
-- Writing the macro
--------------------------------------------------------------------------------------------

--- Brings the game macro in line with the saved state.
---@param allowCreate boolean Create the macro when it doesn't exist
---@param report boolean? When queued, print the outcome once combat ends
---@return GirthBindSyncResult result
---@return string? err User-facing reason, for RESULT.ERROR
function Macro:Sync(allowCreate, report)
    if InCombatLockdown() then
        local pending = self.pending or {}
        pending.allowCreate = pending.allowCreate or allowCreate
        pending.report = pending.report or report
        self.pending = pending
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        Log.Info("In combat; macro update queued")
        return RESULT.QUEUED
    end
    self.pending = nil

    local body = self:CurrentBody()
    if #body > Macro.MAX_BODY then
        Log.Error("Macro body is %d characters (limit %d)", #body, Macro.MAX_BODY)
        return RESULT.ERROR, L["MACRO_TOO_LONG"]:format(#body, Macro.MAX_BODY)
    end

    local name = self:GetName()
    local exists, index = self:Exists()
    if not exists then
        if not allowCreate then
            Log.Debug("Macro %s not found; not creating it now", name)
            return RESULT.MISSING
        end
        local numAccount = GetNumMacros()
        local maxAccount = _G.MAX_ACCOUNT_MACROS or Macro.FALLBACK_MAX_ACCOUNT_MACROS
        if numAccount >= maxAccount then
            Log.Error("Account macros full (%d/%d)", numAccount, maxAccount)
            return RESULT.ERROR, L["MACRO_ACCOUNT_FULL"]:format(numAccount, maxAccount)
        end
        local ok, id = pcall(CreateMacro, name, Macro.ICON, body, false)
        if not ok or not id then
            Log.Error("CreateMacro failed: %s", tostring(id))
            return RESULT.ERROR, L["MACRO_CREATE_FAILED"]:format(name, tostring(id))
        end
        Log.Info("Created macro %s (ID %s)", name, tostring(id))
        Log.Debug("Macro body:\n%s", body)
        self:SendMessage(MESSAGES.MACRO_CHANGED)
        return RESULT.CREATED
    end

    local _, icon, oldBody = GetMacroInfo(index)
    if oldBody == body then
        Log.Debug("Macro %s already up to date", name)
        return RESULT.UNCHANGED
    end
    local ok, err = pcall(EditMacro, index, name, icon, body)
    if not ok then
        Log.Error("EditMacro failed: %s", tostring(err))
        return RESULT.ERROR, L["MACRO_EDIT_FAILED"]:format(name, tostring(err))
    end
    Log.Info("Updated macro %s (ID %d)", name, index)
    Log.Debug("Macro body:\n%s", body)
    self:SendMessage(MESSAGES.MACRO_CHANGED)
    return RESULT.UPDATED
end

--- One chat line telling the user what just happened to the macro.
---@param result GirthBindSyncResult
---@param err string?
function Macro:Report(result, err)
    local name = Util.Color(GOLD, self:GetName())
    if result == RESULT.CREATED then
        Log.Print(L["MACRO_CREATED"], name, self:Describe(), Util.Color(WHITE, "/gb pickup"))
    elseif result == RESULT.UPDATED or result == RESULT.UNCHANGED then
        Log.Print(L["MACRO_UPDATED"], name, self:Describe())
    elseif result == RESULT.QUEUED then
        Log.Print(L["MACRO_QUEUED"], name)
    elseif result == RESULT.ERROR then
        Log.Print(err or L["MACRO_UNKNOWN_ERROR"])
    end
end

--------------------------------------------------------------------------------------------
-- Binding
--------------------------------------------------------------------------------------------

--- Rewrites the macro to target this enemy. Refuses (and keeps the old binding) when the
--- rendered body would be too long or the macro can't be written.
---@param enemy { name: string, npcId: integer? }
---@return boolean ok
function Macro:Bind(enemy)
    local name = type(enemy) == "table" and type(enemy.name) == "string" and Util.Trim(enemy.name) or ""
    if name == "" or Util.IsSecret(enemy.name) then
        Log.Error("Bind called without a usable name")
        return false
    end
    local bound = { name = name, npcId = tonumber(enemy.npcId) }

    local body = self:RenderFor(bound, self:GetTemplate())
    if #body > Macro.MAX_BODY then
        Log.Print(L["BIND_TOO_LONG"], Util.Color(WHITE, name), #body, Macro.MAX_BODY)
        return false
    end

    local previous = self:GetBound()
    Settings().bound = bound
    local result, err = self:Sync(true, true)
    if result == RESULT.ERROR then
        Settings().bound = previous
        self:Report(result, err)
        return false
    end
    Log.Info("Bound %s (NPC %s)", name, tostring(bound.npcId))
    self:SendMessage(MESSAGES.BOUND_CHANGED, bound)
    self:Report(result)
    return true
end

--- Binds the player's current target (/gb bind).
---@return boolean ok
function Macro:BindTarget()
    if not UnitExists("target") then
        Log.Print(L["BIND_NO_TARGET"])
        return false
    end
    local guid, name = UnitGUID("target"), UnitName("target")
    if Util.IsSecret(guid) or Util.IsSecret(name) then
        Log.Warn("Target identity is secret")
        Log.Print(L["BIND_TARGET_SECRET"])
        return false
    end
    if not name then
        Log.Error("UnitName returned nil for an existing target (guid=%s)", tostring(guid))
        Log.Print(L["BIND_TARGET_UNREADABLE"])
        return false
    end
    return self:Bind({ name = name, npcId = Util.ParseNpcId(guid) })
end

--- Forgets the bound enemy; the macro goes back to doing nothing.
---@return boolean changed
function Macro:Clear()
    local bound = self:GetBound()
    if not bound then
        return false
    end
    Settings().bound = nil
    local result, err = self:Sync(false, true)
    self:SendMessage(MESSAGES.BOUND_CHANGED, nil)
    Log.Print(L["BOUND_CLEARED"], Util.Color(WHITE, bound.name))
    if result == RESULT.ERROR or result == RESULT.QUEUED then
        self:Report(result, err)
    end
    return true
end

--------------------------------------------------------------------------------------------
-- Template
--------------------------------------------------------------------------------------------

--- Why a template can't be saved, or nil when it can. Unknown tokens are only a warning.
---@param text any
---@return string? err
function Macro:ValidateTemplate(text)
    if type(text) ~= "string" then
        return L["TEMPLATE_INVALID"]
    end
    local bound = self:GetBound()
    local body
    if bound then
        body = self:RenderFor(bound, text)
    else
        body = Template.Render(text, nil, true)
    end
    if #body > Macro.MAX_BODY then
        return L["TEMPLATE_TOO_LONG"]:format(#body, Macro.MAX_BODY)
    end
    return nil
end

---@param text string
---@return boolean ok
---@return string? err
function Macro:SetTemplate(text)
    local err = self:ValidateTemplate(text)
    if err then
        Log.Print(err)
        return false, err
    end
    Settings().macro.body = (text:gsub("\r\n?", "\n"))
    local result, syncErr = self:Sync(true, true)
    self:SendMessage(MESSAGES.MACRO_CHANGED)
    if result ~= RESULT.UNCHANGED then
        self:Report(result, syncErr)
    end
    return true
end

---@return boolean ok
function Macro:ResetTemplate()
    return (self:SetTemplate(Template.DEFAULT_BODY))
end

--------------------------------------------------------------------------------------------
-- Name
--------------------------------------------------------------------------------------------

--- Why the macro can't be renamed to this, or nil when it can.
---@param newName any
---@return string? err
function Macro:ValidateName(newName)
    newName = Util.Unquote(type(newName) == "string" and newName or "")
    if newName == "" then
        return L["RENAME_EMPTY"]
    end
    local length = Util.Utf8Len(newName)
    if length > Database.MAX_MACRO_NAME then
        return L["RENAME_TOO_LONG"]:format(newName, length, Database.MAX_MACRO_NAME)
    end
    local oldName = self:GetName()
    if newName == oldName then
        return nil
    end
    -- Renaming in combat could leave the saved name pointing at nothing, and the queued
    -- update would then create a second macro.
    if InCombatLockdown() then
        return L["RENAME_COMBAT"]
    end
    -- A name that's already taken is allowed: GirthBind adopts that macro (see Adopt).
    return nil
end

--- True when `name` belongs to a macro other than the one GirthBind manages now.
---@param name string
---@return boolean
function Macro:IsOtherMacro(name)
    local _, index = self:Exists()
    local other = GetMacroIndexByName(name)
    return other ~= nil and other > 0 and other ~= index
end

--- Points GirthBind at a macro the user already has and overwrites its body with the rendered
--- template. Asked for by naming it, so it isn't refused; the macro GirthBind managed before
--- is left exactly as it was, and is no longer updated.
---@param newName string
---@return boolean ok
function Macro:Adopt(newName)
    local oldName = self:GetName()
    local hadOld = self:Exists()
    Settings().macro.name = newName
    local result, err = self:Sync(true, true)
    if result == RESULT.ERROR then
        Settings().macro.name = oldName
        self:Report(result, err)
        return false
    end
    Log.Info("Adopted existing macro %s (was managing %s)", newName, oldName)
    if hadOld then
        Log.Print(L["RENAME_ADOPTED_OLD_KEPT"], Util.Color(GOLD, newName), Util.Color(GOLD, oldName))
    else
        Log.Print(L["RENAME_ADOPTED"], Util.Color(GOLD, newName))
    end
    self:SendMessage(MESSAGES.MACRO_CHANGED)
    return true
end

--- Renames the macro in place, so action bar slots holding it keep working. Naming another
--- existing macro adopts that one instead.
---@param newName string
---@return boolean ok
function Macro:Rename(newName)
    local err = self:ValidateName(newName)
    if err then
        Log.Print(err)
        return false
    end
    newName = Util.Unquote(newName)
    local oldName = self:GetName()
    if newName == oldName then
        return true
    end
    if self:IsOtherMacro(newName) then
        return self:Adopt(newName)
    end

    local exists, index = self:Exists()
    if not exists then
        Settings().macro.name = newName
        Log.Print(L["RENAME_PENDING"], Util.Color(GOLD, newName))
        self:SendMessage(MESSAGES.MACRO_CHANGED)
        return true
    end

    local _, icon, body = GetMacroInfo(index)
    local ok, editErr = pcall(EditMacro, index, newName, icon, body)
    if not ok then
        Log.Error("EditMacro rename failed: %s", tostring(editErr))
        Log.Print(L["RENAME_FAILED"], Util.Color(GOLD, oldName), tostring(editErr))
        return false
    end
    Settings().macro.name = newName
    Log.Print(L["RENAME_DONE"], Util.Color(GOLD, oldName), Util.Color(GOLD, newName))
    self:SendMessage(MESSAGES.MACRO_CHANGED)
    return true
end

--------------------------------------------------------------------------------------------
-- Cursor and creation
--------------------------------------------------------------------------------------------

--- Puts the macro on the cursor (/gb pickup), creating it first if needed.
---@return boolean ok
function Macro:Pickup()
    if InCombatLockdown() then
        Log.Print(L["PICKUP_COMBAT"], Util.Color(WHITE, "/gb pickup"))
        return false
    end
    local result, err = self:Sync(true)
    if result == RESULT.ERROR then
        self:Report(result, err)
        return false
    end
    local _, index = self:Exists()
    local ok, pickupErr = pcall(PickupMacro, index)
    if not ok then
        Log.Error("PickupMacro failed: %s", tostring(pickupErr))
        Log.Print(L["PICKUP_FAILED"], tostring(pickupErr), Util.Color(WHITE, "/macro"), Util.Color(GOLD, self:GetName()))
        return false
    end
    Log.Print(L["PICKUP_DONE"], Util.Color(GOLD, self:GetName()), self:Describe())
    return true
end

--- Creates the (possibly idle) macro if it doesn't exist yet, so it can go on a bar before
--- anything is bound. Called when the Options page opens.
function Macro:EnsureExists()
    if InCombatLockdown() or self:Exists() then
        return
    end
    local result, err = self:Sync(true)
    if result == RESULT.CREATED or result == RESULT.ERROR then
        self:Report(result, err)
    end
end
