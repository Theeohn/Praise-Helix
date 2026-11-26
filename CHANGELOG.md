# Changelog

Format: [keep a changelog](https://keepachangelog.com/en/1.1.0/).
Version headings match `manifest.json`'s `version`.

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
