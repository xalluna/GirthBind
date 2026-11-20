# GirthBind

A World of Warcraft: Forever addon that keeps **one macro** targeting the enemy you bind. Find a
quest, pick one of its enemies, press **Bind**, and the macro now targets (and marks) that enemy.

Addons can't target units themselves (targeting and raid marks are protected actions), so
GirthBind writes a macro that does it when you press it.

## Features

- **Quest lookup window** (`/gb`): search every quest by name, or browse your quest log. Each quest
  lists its objectives with the enemies that serve them (kills, kill credit, item droppers and
  special objectives), each with a **Bind** button. Powered by [QuestieDB](https://github.com/Questie/QuestieDB).
- **Quest menus**: a **GirthBind** submenu in quest right-click menus opens the window on that
  quest or binds an enemy in one click. It's added to:
  - Questie's quest tracker
  - Blizzard's objective tracker and quest log
  - EllesmereUI's custom quest tracker
- **Template macro body**: write the macro yourself, with `$Target.Name$` where the enemy's name
  goes. The Options page shows a live preview and character count.
- Works without QuestieDB: `/gb bind` and the Options page still work, and the quest features
  explain what's missing.

## Commands

| Command | What it does |
| --- | --- |
| `/gb` | Open the lookup window on your quest log |
| `/gb lookup [questName]` | Search for a quest; exactly one exact (case-insensitive) match opens it |
| `/gb idlookup <questId>` | Open a quest by ID |
| `/gb bind` | Bind your current target |
| `/gb pickup` | Put the macro on your cursor to drop on an action bar |
| `/gb options` | Open Esc > Options > AddOns > GirthBind |
| `/gb debug [log\|info\|warning\|error\|none]` | Show or set diagnostic chat output |
| `/gb help` | List commands |

## Options

Esc > Options > AddOns > **GirthBind**:

- **Macro name**: the macro GirthBind manages (default `GirthBind`, up to 16 characters).
  Renaming edits it in place, so action bar slots keep working. Naming a macro you already have
  makes GirthBind manage that one instead: its body is overwritten right away, and the macro
  GirthBind managed before is left as it was.
- **Macro body**: the template. The default is:

  ```
  /targetexact $Target.Name$
  /cleartarget [dead]
  /tm 8
  ```

- Reset body, the bound enemy with **Clear**, **Pick up macro**, and the debug level.

### Tokens

| Token | Replaced with |
| --- | --- |
| `$Target.Name$` | The bound enemy's name |
| `$$` | A literal `$` |

Token names are case-sensitive. Anything token-shaped that isn't a known token (`$Target.Nmae$`)
is left exactly as typed, and the Options page warns about it. A body that would render past the
macro limit of 255 characters is refused.

Until you bind an enemy the macro is `/stopmacro`. It's created the first time you open the
Options page, use `/gb pickup`, or bind something. Changes made in combat apply when combat ends.

## Requirements

- WoW Forever (interface 16001)
- Optional: [QuestieDB](https://www.curseforge.com/wow/addons/questiedb) (contract 4) for quest
  lookup and quest menus; Questie and EllesmereUI for their menus.

## Development

### Layout

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

### Tests and lint

The tests boot the real Ace3 libraries and every TOC file inside a fake client
(`tests/helpers/wow.lua`), so they cover lifecycle, events, combat queueing and macro writes. They
run in a Lua 5.1 Docker image, the same one CI uses:

```powershell
./scripts/test.ps1
```

`-Only busted` or `-Only luacheck` runs one of the two; `-Rebuild` rebuilds the image.

For editor support, install the LuaLS extension plus Ketho's *WoW API* extension; `.luarc.json`
adds `libs/` and `types/` to the workspace.

### Trying it in game

```powershell
./scripts/deploy-test.ps1
```

This copies the addon to `Interface\AddOns\GirthBind.Test`, with its own TOC and SavedVariables
(`GirthBindTestDB`). `/reload` loads it. If the CurseForge build (`GirthBind`) is also enabled,
the test copy turns itself off and says so in chat. The script finds the WoW Forever AddOns folder
on a local drive; pass `-AddOnsPath` or set `GIRTHBIND_ADDONS` to choose one.

### Releasing

Push a `v*` tag (for example `v2.0.0`). The Release workflow runs lint and tests, then the
[BigWigs packager](https://github.com/BigWigsMods/packager) builds the zip and uploads it to
CurseForge project 1815823 and a GitHub release. Add the CHANGELOG entry before tagging.

The repository needs a `CF_API_KEY` secret holding a CurseForge API token.

## License

MIT. Ace3 is distributed under its own BSD-style license (see `libs/*/LICENSE.txt`).
