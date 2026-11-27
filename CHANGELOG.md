# Changelog

Format: [keep a changelog](https://keepachangelog.com/en/1.1.0/).
Version headings match `manifest.json`'s `version`.

## [1.0] - 2026-11-26

### Changed

- BRDJESUS: a crowd press about every 0.5 s, followers / noise / herders /
  trolls 45/35/13/7, the crowd's size swinging ±50%, and a 1 in 4 event
  chance every 15 s. Your own buttons go straight through.
- HELIX: a wilder crowd, a press about every 0.22 s, followers / noise /
  herders / trolls 40/40/11/9, the crowd's size swinging ±60%, and a 1 in 3
  event chance every 10 s. Your own inputs still reach the game every
  0.6 s.
- Time lost to a press's hold is now won back by the next gaps (within each
  10 s), so the fast speeds still average out close to their rate.
- The event roll runs on its own timer, separate from the 10 s crowd beat.

## [0.9] - 2026-11-26

### Changed

- The random presses are now a virtual Twitch chat. Each press comes from
  one of four kinds of viewer: followers copy your own inputs a little
  late, noise presses anything allowed, herders repeat the crowd's last
  press, trolls press START or the griefer's direction. Shares are
  56/34/7/3 on BRDJESUS and 45/35/13/7 on HELIX.
- Followers remember your last 8 inputs, in order. Mashing one button
  counts twice at most, each input is used once, and the memory carries
  over between screens. It's forgotten when you open a settings screen or
  turn the mod off, and the START+SELECT off switch is never remembered.
- Speeds: OFF / BRDJESUS (a press about every 0.7 s) / HELIX (about every
  0.4 s). DIGRAT is gone; an old DIGRAT setting reads as OFF.
- Every 10 s the crowd's size re-rolls: the rate swings x0.6/1/1.4 on
  BRDJESUS and x0.5/1/1.5 on HELIX, so the gaps average out to the speed.
- HELIX: one of your inputs reaches the game every 0.6 s (was 0.9 s), the
  oldest one still waiting rather than only the last one. The followers draw
  from the same queue, so each input still goes in once.

### Added

- EVENTS: ON / OFF (ON by default). Now and then a START riot (3 to 6
  STARTs), a 4-second lull at a third of the rate, or a streak of one
  direction (3 to 5 presses). More often on HELIX.

## [0.13.2] - 2026-11-26

### Changed

- A, B, START and SELECT are held for 2 frames now, not tapped for one:
  long enough to register reliably, still short of the fastest interval.
- The mod never has two of its own presses active at once: the chaos and
  your own command echoed back in HELIX now wait for each other. Your own
  START+SELECT is read apart from all of this and still always works.
- The SELECT+A/B display-chord guard (0.13) is load-bearing again now that
  SELECT is genuinely held for a couple of frames, not just a tap.

## [0.13.1] - 2026-11-26

### Changed

- Only a direction (UP/DOWN/LEFT/RIGHT) is held (12 frames). A, B, START
  and SELECT are each a single tap now -- pressed and immediately let go,
  never held across frames.
- As a consequence, our own SELECT can no longer be caught "down" by
  anything outside the one instant of its own tap, which is what let the
  0.13 gamepad chord ever happen in the first place; that guard stays in
  as a second layer regardless.

## [0.13] - 2026-11-26

### Fixed

- On a gamepad, holding SELECT (the chaos, or your own command echoed back
  in HELIX) could complete the recomp's own SELECT+A / SELECT+B shortcut
  (COLORS / TILT) the instant you pressed A or B for an ordinary reason --
  that shortcut is read straight off whether SELECT is down, which can't
  tell our hold from yours. Our held SELECT now steps aside for exactly
  that one real press and comes straight back after. Your own SELECT,
  genuinely held, still works the shortcut as it always did. The keyboard
  path (a literal "3" key) was never reachable by the mod to begin with.

## [0.12] - 2026-11-26

### Changed

- HELIX: a random press every 0.3 s (was 0.2 s), and one of your own inputs
  reaches the game every 0.9 s (was 1.3 s).
- Every press, random or your HELIX command, is held for 12 frames (was 8).

## [0.11] - 2026-11-26

### Changed

- Never A or START on the START menu's SAVE row, and never A or START while
  YES is highlighted in the save screen ("save?" and "overwrite?"), on all
  three generations. It can still pick NO or back out with B, so your game
  is only ever saved by you.

## [0.1] - 2026-11-26

First public release.

- PRAISE HELIX speeds: OFF, DIGRAT (a random press every 0.9 s), BRDJESUS
  (every 0.5 s) and HELIX (every 0.2 s).
- HELIX also queues your own buttons: one of your inputs reaches the game
  every 1.3 s (the last one pressed, or the one held).
- Random buttons: UP, DOWN, LEFT, RIGHT, A, B, START and SELECT. Every 10 s
  the direction mix swings between 8:2, 7:3 and 6:4 (8:2 a little less
  often).
- Hold START+SELECT for a quarter second to turn it OFF, at every speed
  (keyboard, pad, or two fingers on touch). A "STRTSLCT" row tops the
  options page.
- Starts only once you're back in the overworld after turning it on.
- Goes nearly everywhere: the bag, party, PC, shops, POKéMON CENTER,
  Day-Care, NPC questions, berry trees and SAVE, mod-rebuilt screens
  included. Never A on RELEASE; never in settings, the Mod Manager, a mod's
  START row, link play or the title.
- BATTLES: OFF / TRAINERS / ALL.
- Light on low-end hardware: nothing per frame when OFF; the screen is only
  read when a press is due or the screen changes.
