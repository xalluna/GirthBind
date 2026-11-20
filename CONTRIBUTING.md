# Developing GirthBind

How the addon is built, tested, and released. For what it does and how to use it, see the
[README](README.md).

## Layout

```
GirthBind.toc       load order; X-Curse-Project-ID for releases
embeds.xml          vendored Ace3 (libs/), unmodified
locales/enUS.lua    every user-facing string (AceLocale)
src/
  Init.lua          namespace, AceAddon object, dev-copy yield check
  Core/             Util, Log, Database (AceDB schema + repair)
  Macro/            Template (token engine, pure) and Macro (the game macro)
  Quest/            QuestData (the only QuestieDB reader), QuestSearch, QuestLog
  UI/               LookupWindow, Options (AceConfig)
  Integrations/     MenuModel (what the menu entry contains) + one renderer per menu system
  Commands.lua      /gb
  Addon.lua         lifecycle (loads last)
tests/              busted specs; helpers/ holds the fake client, fake QuestieDB, and loader
types/              LuaLS declarations (editor-only)
```

Modules only touch the game in `OnEnable`, never at file load, so a disabled copy stays inert.
Modules talk through AceEvent messages (`GIRTHBIND_BOUND_CHANGED`, `GIRTHBIND_MACRO_CHANGED`).

New user-facing text goes in `locales/enUS.lua`; a test fails if the source uses a key that isn't
defined there.

## Tests and lint

The tests boot the real Ace3 libraries and every TOC file inside a fake client
(`tests/helpers/wow.lua`), so they cover lifecycle, events, combat queueing and macro writes. They
run in a Lua 5.1 Docker image, the same one CI uses:

```powershell
./scripts/test.ps1
```

`-Only busted` or `-Only luacheck` runs one of the two; `-Rebuild` rebuilds the image.

For editor support, install the LuaLS extension plus Ketho's *WoW API* extension; `.luarc.json`
adds `libs/` and `types/` to the workspace.

## Trying it in game

```powershell
./scripts/deploy-test.ps1
```

This copies the addon to `Interface\AddOns\GirthBind.Test`, with its own TOC and SavedVariables
(`GirthBindTestDB`). `/reload` loads it. If the CurseForge build (`GirthBind`) is also enabled,
the test copy turns itself off and says so in chat. The script finds the WoW Forever AddOns folder
on a local drive; pass `-AddOnsPath` or set `GIRTHBIND_ADDONS` to choose one.

`/console scriptErrors 1` makes Lua errors pop up in game instead of failing silently.

## Releasing

Push a `v*` tag (for example `v2.0.0`). The Release workflow runs lint and tests, then the
[BigWigs packager](https://github.com/BigWigsMods/packager) builds the zip and uploads it to
CurseForge project 1815823 and a GitHub release. Add the CHANGELOG entry before tagging.

The repository needs a `CF_API_KEY` secret holding a CurseForge API token.
