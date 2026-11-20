# GirthBind

**One button that finds your quest target.** Tell GirthBind which enemy you're hunting, and its
macro targets that enemy and marks it with a skull every time you press it. No more tab-targeting
through a crowd looking for the one wolf the quest wants.

Pick the enemy straight from a quest. GirthBind looks up every enemy a quest involves (the ones
you kill, the ones that drop the items you need, and the ones that give kill credit) and gives
each one a **Bind** button.

> Addons can't target enemies by themselves. Only a key press or click can, so GirthBind writes a
> macro for you to press. You choose the enemy; the macro does the targeting.

## Install

1. Install **GirthBind** with the CurseForge app, or extract it into
   `World of Warcraft\_forever_\Interface\AddOns`.
2. For quest lookups, also install **[QuestieDB](https://www.curseforge.com/wow/addons/questiedb)**.
   Without it you can still bind your current target (see below), but quest search and the quest
   menus are switched off.
3. Optional: GirthBind adds itself to the quest menus of **Questie** and **EllesmereUI** if you use
   them.

GirthBind is for WoW Forever.

## Quick start

1. Type **`/gb`**. The GirthBind window opens, showing the quests in your quest log.
2. Click a quest. Its objectives appear on the right, each with the enemies that serve it.
3. Click **Bind** next to the enemy you want.
4. Type **`/gb pickup`** and drop the macro on an action bar. You only do this once: the macro
   stays on your bar and changes whenever you bind a different enemy.
5. Press the button. It targets the enemy and puts a skull on it.

## Binding an enemy

There are three ways to choose the enemy the macro targets. Only one enemy is bound at a time;
binding another replaces it.

### From the GirthBind window

Open it with **`/gb`**.

- **Left side:** your quest log. Type in the search box to search *every* quest instead, not just
  the ones you have. The first search takes a moment while GirthBind indexes the quests
  ("Indexing quests…").
- **Right side:** the selected quest's objectives. Each one says how its enemies count:
  - **Kill**: enemies the quest asks you to kill.
  - **Kill credit**: every enemy that counts toward a kill objective.
  - **Dropped by**: enemies that drop an item the quest needs.
  - **Special objective**: enemies tied to a quest event.
- Enemies in the quest's own zone are listed first, then by level. Long lists show the first 10;
  click **Show N more…** for the rest.
- Hover an enemy for its level, rank (Elite, Rare…), and zone.
- Click **Bind**. The row turns to **Bound**, and the bottom of the window shows what the macro
  targets now.

The window stays open after you bind, so you can switch enemies quickly. Press **Esc** to close it.
Drag it to move it; it reopens where you left it.

You can also jump straight to a quest:

- **`/gb lookup Kobold Camp Cleanup`** opens that quest if exactly one quest has that name.
  Otherwise it shows the matching quests to pick from. Partial names work too.
- **`/gb idlookup 7`** opens a quest by its quest ID.

### From a quest's right-click menu

Right-click a quest in your quest tracker or quest log and open the **GirthBind** submenu:

- **Open in GirthBind…** opens the window on that quest.
- The quest's enemies are listed underneath. Click one to bind it right away. The one bound now
  says *(bound)*. If a quest has more than 15 enemies, the last item opens the window for the rest.

The GirthBind entry appears in:

- Questie's quest tracker
- the game's own quest tracker (right-click the quest's title)
- the quest log on the world map
- EllesmereUI's quest tracker

If the entry is greyed out, hover it to see why: usually the quest has no enemies to bind (a
delivery quest, say), or QuestieDB isn't installed.

### From your current target

Target the enemy and type **`/gb bind`**. This works for anything you can target, with or without
QuestieDB.

## The macro

GirthBind manages one macro, named **GirthBind** by default. Find it in `/macro` like any other, or
type **`/gb pickup`** to put it on your cursor.

Out of the box, pressing it runs:

```
/targetexact <enemy name>
/cleartarget [dead]
/tm 8
```

That targets a nearby enemy with exactly that name, lets go of it if it's already dead (press
again for the next one), and marks it with a skull.

Until you bind something, the macro does nothing. It's created the first time you open the
GirthBind options, use `/gb pickup`, or bind an enemy. You can change its icon in `/macro`;
GirthBind keeps your icon.

### Changing what the macro does

Open **Esc → Options → AddOns → GirthBind** (or type `/gb options`) and edit **Macro body**. Write
any macro you like, and put **`$Target.Name$`** where the bound enemy's name should go. Click
**Accept** to save; the macro updates right away.

Some ideas:

| You want | Macro body |
| --- | --- |
| Target and start attacking | `/targetexact $Target.Name$`<br>`/startattack` |
| Send your pet in | `/targetexact $Target.Name$`<br>`/petattack` |
| Use a red X instead of a skull | `/targetexact $Target.Name$`<br>`/cleartarget [dead]`<br>`/tm 7` |
| Just target, no mark | `/targetexact $Target.Name$`<br>`/cleartarget [dead]` |

Raid mark numbers for `/tm`: 8 skull, 7 cross, 6 square, 5 moon, 4 triangle, 3 diamond,
2 circle, 1 star. In a raid, marking needs leader or assist.

Good to know:

- Under the editor, a **preview** shows the exact macro and its length. Macros are limited to 255
  characters. A body that's too long isn't saved, and if a long enemy name would push it over, that
  bind is refused and the macro keeps its old enemy.
- Tokens are case-sensitive. A typo like `$Target.Nmae$` isn't replaced; the options page warns you
  about it.
- To type an actual dollar sign, write `$$`.
- **Reset body** puts back the default.

## Options

**Esc → Options → AddOns → GirthBind**, or `/gb options`:

| Option | What it does |
| --- | --- |
| **Macro name** | The macro GirthBind manages (up to 16 characters). Renaming keeps it on your action bars. |
| **Pick up macro** | Puts the macro on your cursor to drop on a bar. |
| **Macro body** | What the macro does; see above. |
| **Reset body** | Restores the default macro body. |
| **Bound enemy** / **Clear** | Shows who the macro targets now. Clear forgets them, so the macro does nothing. |
| **Debug output** | Extra chat messages for troubleshooting. Leave it on *None* normally. |

**Using a macro you already have:** if you type the name of one of your existing macros into
**Macro name**, GirthBind takes it over and **overwrites its body** right away. The macro GirthBind
was using before is left as it was and stops updating. To go back, type the old name again.

Settings are shared by all your characters.

## Commands

| Command | What it does |
| --- | --- |
| `/gb` | Open the GirthBind window |
| `/gb lookup <quest name>` | Find a quest by name |
| `/gb idlookup <quest ID>` | Open a quest by its ID |
| `/gb bind` | Bind your current target |
| `/gb pickup` | Put the macro on your cursor |
| `/gb options` | Open the GirthBind options |
| `/gb debug <level>` | Troubleshooting output: `none` (normal), `error`, `warning`, `info`, or `log` (everything) |
| `/gb help` | List these commands in chat |

## Combat

- You can bind during combat. The macro can't be changed until combat ends, so GirthBind tells you
  it's waiting and updates it the moment you're out.
- Renaming the macro, picking it up, and opening the options page all wait until you're out of
  combat.
- In combat (and in some instances) the game hides who your target is from addons, so `/gb bind`
  may say your target's identity is hidden. Bind before the pull, or from the window.

## Troubleshooting

**Pressing the macro does nothing.**
Nothing is bound yet, or no enemy with that exact name is close enough to target. Check what the
bottom of the GirthBind window says, or the **Bound enemy** line in the options.

**It keeps targeting a dead one.**
The default macro lets go of dead targets; press it again for the next living one. If you've
edited the body, keep the `/cleartarget [dead]` line.

**"Quest lookup needs the QuestieDB addon."**
Install and enable QuestieDB, then reload. If it says QuestieDB is the wrong version, update
whichever of GirthBind and QuestieDB is older.

**There's no GirthBind entry in a quest menu.**
Right-click the quest's title (not an objective line). In the game's own tracker, keep the cursor
over the title as you right-click.

**"Your account macros are full."**
Delete a macro you don't use; GirthBind needs one free account macro slot.

**The quest lists an enemy twice / lists the wrong ones.**
Enemy data comes from QuestieDB. Enemies that share a name appear once, because the macro targets
by name. Report data problems to Questie.

**Reporting a bug**
Type `/gb debug log`, do the thing that goes wrong, and include the chat output with your report.
Then `/gb debug none` to turn it off.

## License

MIT. GirthBind includes the Ace3 libraries, under their own license.
