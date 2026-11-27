# Praise Helix

**Twitch Plays Pokémon, on top of your own buttons.** While you play, a
virtual Twitch chat plays along: a crowd that mostly tries to do what *you*
are doing, a little late, with noise, herders and the odd troll mixed in.
It presses UP, DOWN, LEFT, RIGHT, A, B, START and SELECT, and it works on
**Gen 1, Gen 2 and Gen 3**.

It goes nearly everywhere you can, the way the stream did: the bag, the
party, the PC, shops, the POKéMON CENTER, the Day-Care, NPCs' questions,
berry trees. It stays out of the few places that could actually hurt your
game or your setup, it never presses A on **RELEASE**, it never saves your
game, and holding **START+SELECT** turns it off.

## Install

**Easiest:** in the game's launcher, use **Import mod .zip** (or just drag
`Praise-Helix-v1.0.zip` onto the game window). Works the same on Windows, Mac and
Linux.

**Manually:** unzip `Praise-Helix-v1.0.zip` into a `praise_helix` folder inside the
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
| `PRAISE HELIX` | OFF / BRDJESUS / HELIX | How big and wild the crowd is. BRDJESUS: a press about every 0.5 seconds, and your own buttons go straight through as always. HELIX: a wilder crowd, a press about every 0.22 seconds, **and** your own buttons go into the queue like a TPP viewer's (see below). OFF: no crowd. |
| `EVENTS` | ON / OFF | Now and then, something happens in chat: a START riot, a lull, or a streak of one direction (see below). ON by default. |
| `BATTLES` | OFF / TRAINERS / ALL | Which battles the crowd plays in. TRAINERS (the default) leaves wild battles to you, so a random FIGHT can't knock out a legendary or a shiny you wanted to catch. |

**It starts in the overworld.** After you turn it on (or change the speed),
nothing happens until you've closed the menus and are back walking around.
If you change your mind on the way out, there's nothing to fix.

**Who's in the crowd.** Every press comes from one of four kinds of viewer:

| | BRDJESUS | HELIX |
| --- | --- | --- |
| **Followers** copy one of your own inputs, a little late | 45% | 40% |
| **Noise** presses anything the screen allows | 35% | 40% |
| **Herders** repeat the crowd's last press | 13% | 11% |
| **Trolls** press START, or the griefer's favourite direction | 7% | 9% |

When there's nothing of yours left to copy, the followers' turn goes to the
rest of the crowd. The noise's mix of directions to everything else swings
every 10 seconds between 8:2, 7:3 and 6:4 (8:2 a little less often).

**What the followers remember.** Your presses, in order, the last 8 of them.
Mashing one button only counts twice in a row, so frustration doesn't snowball.
Each remembered input is copied once, and it carries over from screen to
screen, so a press you made in one place can turn up in the next. They're
forgotten when you open a settings screen or turn the mod off. Your
START+SELECT off switch is never remembered.

**The crowd's size moves.** Every 10 seconds it re-rolls: busier, normal or
quieter (±50% on BRDJESUS, ±60% on HELIX). None of the gaps are exact; they
average out to the speed.

**Events** (with EVENTS on). On BRDJESUS there's a 1 in 4 chance one starts
every 15 seconds (about one a minute); on HELIX, 1 in 3 every 10 seconds
(about one every 30 seconds):

- **Riot:** 3 to 6 STARTs in a row, like the start9 protests.
- **Lull:** 4 seconds at a third of the rate.
- **Streak:** one direction, 3 to 5 times over.

**HELIX, the true TPP experience.** Your presses don't go straight to the
game. Every 0.6 seconds, one of your inputs is fed in among the chaos: the
oldest one still waiting, or the button you're holding. Holding RIGHT walks
one step every 0.6 seconds; tapping UP, LEFT and B sends all three, one by
one. The followers draw from the same queue, so your inputs can get through
sooner than 0.6 seconds, but each one only ever goes in once.

**Hold START+SELECT to stop, at every speed, HELIX included.** Press START
and SELECT together and hold them for a quarter of a second. That works on a
keyboard, a pad, or two fingers on the touch screen's START and SELECT.
They're read straight from your controller, ahead of HELIX's queue. PRAISE
HELIX goes back to OFF and stays off (it's saved) until you turn it on again
here. A quick brush of both buttons doesn't count, and neither do the mod's
own presses: the crowd presses START and SELECT too, riots included, and
that never stops it. While you're holding them, the crowd starts no new
presses.

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

- Every crowd press, followers' included, goes through the rules above. A
  follower copying your A still never presses it on RELEASE or the save
  screen's YES.
- The crowd's presses come from Praise Helix's own input source. They can't
  release or override a button you're holding, and a random press is never
  the button that completes the soft-reset chord (A+B+START+SELECT).
- **TILT / COLORS can't be hijacked.** On a gamepad, the recomp's own
  SELECT+A (COLORS) and SELECT+B (TILT) display shortcuts fire the instant
  you press a real A or B while SELECT reads as held -- it can't tell your
  hold from ours. So our own held SELECT (the chaos, or your own command
  echoed back in HELIX) steps aside for that one real press and comes
  straight back after. Your own SELECT, really held, still works the
  shortcut as it always did. On keyboard, TILT and COLORS are a literal "3"
  / "2" keypress the mod has no way to send.
- A direction is held for 12 frames, so it takes a real step in the
  overworld. A, B, START and SELECT are held too, just for 2 frames instead
  -- long enough to register, short of the fastest interval.
- The mod never has two of its own presses going at once: the crowd and
  your own queued HELIX command always wait for each other, so only one
  button is ever down from the mod at a time. Your own START+SELECT is
  read apart from all of this and always works.
- Outside HELIX the game sees your START+SELECT as normal presses, so
  stopping it may also open (or close) the START menu.
- Opening OPTIONS or the Mod Manager pauses the chaos, and lifts HELIX's
  queue, so your settings menus always get your buttons directly.
- HELIX only ever changes what the game sees, and only while Praise Helix is
  running. If the mod is turned off, unloaded or stops for any reason, the
  engine's own input is put back within two frames.
- Your own HELIX commands are yours. They aren't limited like the crowd's
  presses, so they go wherever you steer them.
- An old DIGRAT setting from an earlier version reads as OFF; pick
  BRDJESUS or HELIX again.
- **Built light.** When OFF it costs nothing but a counter. When ON it only
  looks at the screen when a press is due or the screen changes: about
  0.4 µs per frame on BRDJESUS and 0.5 µs on HELIX (roughly double that
  without the JIT), against the 16,667 µs a frame has at 60 fps.

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
