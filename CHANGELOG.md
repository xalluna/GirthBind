# Changelog

## 2.0.0

The addon is now **GirthBind**, rebuilt on Ace3 for WoW Forever.

### New

- Quest lookup window (`/gb`, `/gb lookup [questName]`, `/gb idlookup <questId>`). Search every
  quest or browse your quest log, see each objective's enemies, and bind one with a click. Needs
  QuestieDB.
- A **GirthBind** submenu in quest right-click menus: Questie's tracker, Blizzard's objective
  tracker and quest log, and EllesmereUI's custom tracker.
- Options page (Esc > Options > AddOns > GirthBind): macro name, template macro body with a live
  preview, reset, bound enemy with Clear, pick up, and debug level.
- Macro body tokens: `$Target.Name$`, with `$$` for a literal `$`.
- `/gb bind` binds your current target.
- Naming an existing macro on the Options page makes GirthBind manage (and overwrite) that macro.

### Changed

- The slash command is `/gb` (was `/girthbinder`), and bare `/gb` opens the lookup window.
- `/girthbinder target` is now `/gb pickup`.
- Raid marks are part of the macro body (the default ends in `/tm 8`).
- The default macro is named `GirthBind`, and settings live in `GirthBindDB`. Settings from
  GirthBinder aren't carried over.

### Removed

- Saved Current/Previous targets.
- `/girthbinder rename` (use the Options page) and `/girthbinder mark` (edit the macro body).
