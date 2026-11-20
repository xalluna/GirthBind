-- Addon.lua
--
-- Lifecycle. Loads last, once every module has been defined.
--
--   ADDON_LOADED  -> OnInitialize: yield check, SavedVariables
--   PLAYER_LOGIN  -> OnEnable, then each module's OnEnable (events, hooks, slash command)
--
-- Modules keep all side effects in OnEnable, so a yielding dev copy (disabled here) never
-- registers anything.

---@type string, GirthBindNamespace
local ADDON_NAME, ns = ...
local L, Log, Util = ns.L, ns.Log, ns.Util

local GirthBind = ns.addon

function GirthBind:OnInitialize()
    if ns.ShouldYield() then
        ns.yielded = true
        -- AceAddon queues each module for enabling on its own, so disable them all, not just
        -- the addon.
        self:SetEnabledState(false)
        for _, module in self:IterateModules() do
            module:SetEnabledState(false)
        end
        Log.Print(L["YIELD_TO_RELEASE"], Util.Color(Util.COLORS.GOLD, ns.RELEASE_NAME))
        return
    end
    ns.db = ns.Database.Initialize(ns.SV_NAME)
end

function GirthBind:OnEnable()
    local version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
    Log.Debug("Enabled %s %s (macro %s, debug %s)", ADDON_NAME, version, ns.db.global.macro.name, Log.GetLevel())
end
