# Praise Helix

**Twitch Plays Pokémon, on top of your own buttons.** While you play, Praise
Helix presses a random button for you on a timer: UP, DOWN, LEFT, RIGHT, A,
B, START or SELECT. It works on **Gen 1, Gen 2 and Gen 3**.

It goes nearly everywhere you can, the way the stream did: the bag, the
party, the PC, shops, the POKéMON CENTER, the Day-Care, NPCs' questions,
berry trees. It stays out of the few places that could actually hurt your
game or your setup, it never presses A on **RELEASE**, it never saves your
game, and holding **START+SELECT** turns it off.

## Install

**Easiest:** in the game's launcher, use **Import mod .zip** (or just drag
`Praise-Helix-v0.11.zip` onto the game window). Works the same on Windows, Mac and
Linux.

**Manually:** unzip `Praise-Helix-v0.11.zip` into a `praise_helix` folder inside the
game's `mods` folder:

| OS | Mods folder |
| --- | --- |
| Windows | `%APPDATA%\LOVE\pokemon-love2d\mods\praise_helix` |
| macOS | `~/Library/Application Support/LOVE/pokemon-love2d/mods/praise_helix` |
| Linux | `~/.local/share/love/pokemon-love2d/mods/praise_helix` |

(Portable installs keep `mods` in the game's own folder instead.)

Either way, finish by enabling **Praise Helix** in the Mod Manager (`F10`) or a
profile.

Supports Red/Blue/Yellow, Gold/Silver/Crystal, and
Ruby/Sapphire/Emerald/FireRed/LeafGreen.

## Options

In the Mod Manager (`F10`) → **Praise Helix** → **OPTIONS**:

| Option | Values | What it does |
| --- | --- | --- |
| `STRTSLCT` | (just text) | A reminder of the off switch: hold START+SELECT. |
| `PRAISE HELIX` | OFF / DIGRAT / BRDJESUS / HELIX | How hard the chaos hits. DIGRAT: a random press every 0.9 seconds. BRDJESUS: every 0.5 seconds. HELIX: every 0.2 seconds, **and** your own buttons go into the queue like a TPP viewer's (see below). OFF: never. |
| `BATTLES` | OFF / TRAINERS / ALL | Which battles the chaos plays in. TRAINERS (the default) leaves wild battles to you, so a random FIGHT can't knock out a legendary or a shiny you wanted to catch. |

**It starts in the overworld.** After you turn it on (or change the speed),
nothing happens until you've closed the menus and are back walking around.
If you change your mind on the way out, there's nothing to fix.

**The mix keeps moving.** Every 10 seconds the split between directions and
the other four buttons swings to 8:2, 7:3 or 6:4. 8:2 comes up a little less
often than the other two (about 27% against 36% each). Sometimes it wanders,
sometimes it mashes.

**HELIX, the true TPP experience.** Your presses don't go straight to the
game. Every 1.3 seconds, one of your inputs is fed in among the chaos: the
last button you pressed in that window, or the one you're holding. Holding
RIGHT walks one step every 1.3 seconds; tapping A, LEFT and B in one window
sends just the B.

**Hold START+SELECT to stop, at every speed, HELIX included.** Press START
and SELECT together and hold them for a quarter of a second. That works on a
keyboard, a pad, or two fingers on the touch screen's START and SELECT.
They're read straight from your controller, ahead of HELIX's queue. PRAISE
HELIX goes back to OFF and stays off (it's saved) until you turn it on again
here. A quick brush of both buttons doesn't count, and neither do the mod's
own presses: the chaos presses START and SELECT too, and that never stops
it. While you're holding them, the chaos starts no new presses.

## Where the chaos goes

**Everywhere in the game, every button**, including screens a mod has
rebuilt (a new Pokédex, bag or party menu). That covers:

- the overworld, signs, NPCs and their YES/NO questions, berry trees and
  items on the ground, your registered key item (SELECT)
- the START menu: POKéDEX, POKéMON, BAG / ITEM / PACK, POKéGEAR, POKéNAV
  and your trainer card, and everything inside them
- the PC, shops, the POKéMON CENTER, the Day-Care, naming screens,
  evolutions, learning and forgetting moves, the Game Corner
- battles, all of the menu (picked with BATTLES)

**Never A on RELEASE.** In any PC, a random A is never pressed while RELEASE
is highlighted, or anywhere in a release (picking the POKéMON, "are you
sure?", the goodbye). A POKéMON can only ever be released by you.

**Never A or START on SAVE.** The chaos can move the cursor over the START
menu's SAVE row, but never presses A or START on it. If you open the save
screen yourself, it never presses A or START while YES is highlighted (on
"save?" or on "overwrite the old file?"). It can still move to NO and pick
it, or back out with B. Your game is only ever saved by you.

**Never at all.** The chaos pauses here, and stays paused until you're back
in the overworld:

- the **Mod Manager**, every **OPTIONS / settings** screen (the game's, the
  recomp's: controls, touch layout, palettes, shaders, and any mod's), and
  anything opened from them
- **START menu rows that aren't the game's own:** OPTION, MODS, QUIT and any
  row a mod adds, plus whatever that row opens. The chaos can move the
  cursor over them but never presses A on them.
- link battles and trades, the Union Room and wireless, the battle arena
- the title screen, intro and main menu
- the old man's catching demo

## Things to know

- The random presses come from Praise Helix's own input source. They can't
  release or override a button you're holding, and a random press is never
  the button that completes the soft-reset chord (A+B+START+SELECT).
- Each random press is held for a moment (8 frames), so a random direction
  takes one step in the overworld instead of only turning you.
- Outside HELIX the game sees your START+SELECT as normal presses, so
  stopping it may also open (or close) the START menu.
- Opening OPTIONS or the Mod Manager pauses the chaos, and lifts HELIX's
  queue, so your settings menus always get your buttons directly.
- HELIX only ever changes what the game sees, and only while Praise Helix is
  running. If the mod is turned off, unloaded or stops for any reason, the
  engine's own input is put back within two frames.
- Your own HELIX commands are yours. They aren't limited like the random
  presses, so they go wherever you steer them.
- **Built light.** When OFF it costs nothing but a counter. When ON it only
  looks at the screen when a press is due or the screen changes, about
  0.2 µs per frame (HELIX about 0.6 µs; roughly double that without the JIT).

## Credits

**Contributors**

- **Theeohn**: author.
- **Claude** (Anthropic): co-developer.

**With thanks**

- **Twitch Plays Pokémon**: the 2014 stream this recreates.
- **ZyranCZ**: [autofire](https://github.com/ZyranCZ/autofire). Its use of
  the engine's tool-input API was the reference for how Praise Helix presses
  buttons.
- Built for the Pokémon Gen 1 Recompilation Project by BOIS CLUB GAMES, LLC
  (https://github.com/bryanthaboi/gen1recomp).

## License

GPL-3.0 (see `LICENSE`), matching the project it builds on.
