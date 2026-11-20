-- Init.lua
--
-- First addon file to load. Sets up the shared namespace and the AceAddon object every other
-- file hangs its code from. Nothing here touches the game world: side effects (events, slash
-- commands, hooks, frames) wait for OnEnable, so a copy that yields to the release build
-- (see ShouldYield) stays inert.

---@type string, GirthBindNamespace
local ADDON_NAME, ns = ...

-- The name the CurseForge release installs under. Any other folder name (GirthBind.Test, made
-- by scripts/deploy-test.ps1) is a dev copy.
ns.RELEASE_NAME = "GirthBind"
ns.ADDON_NAME = ADDON_NAME
ns.IS_RELEASE = ADDON_NAME == ns.RELEASE_NAME

-- Each copy keeps its own SavedVariables, so a dev copy can never overwrite the release's
-- settings at logout. deploy-test.ps1 writes the same name into the dev copy's TOC.
ns.SV_NAME = ADDON_NAME:gsub("[^%w]", "") .. "DB"

-- Inter-module messages (AceEvent SendMessage), so modules never call each other's UI code.
ns.MESSAGES = {
    BOUND_CHANGED = "GIRTHBIND_BOUND_CHANGED", -- (bound|nil) the bound enemy changed
    MACRO_CHANGED = "GIRTHBIND_MACRO_CHANGED", -- the managed macro's name, body or template changed
}

ns.L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)

ns.addon = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0")

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
local IsAddOnLoadable = C_AddOns and C_AddOns.IsAddOnLoadable
local GetAddOnEnableState = C_AddOns and C_AddOns.GetAddOnEnableState

--- A dev copy steps aside when the release build is installed and enabled, so the two never
--- both own /gb, the macro, and the menu hooks.
---@return boolean
function ns.ShouldYield()
    if ns.IS_RELEASE then
        return false
    end
    if IsAddOnLoaded and IsAddOnLoaded(ns.RELEASE_NAME) then
        return true
    end
    if GetAddOnEnableState and IsAddOnLoadable then
        local enabled = (GetAddOnEnableState(ns.RELEASE_NAME) or 0) > 0
        return enabled and (IsAddOnLoadable(ns.RELEASE_NAME)) and true or false
    end
    return false
end
