-- Praise Helix: Twitch Plays Pokemon chaos, on top of your own buttons.
--
-- With PRAISE HELIX on, a virtual Twitch chat plays along with you: a button
-- -- UP, DOWN, LEFT, RIGHT, A, B, START or SELECT -- is pressed for you every
-- so often, by a crowd that is mostly trying to do what you are doing.
--
--   BRDJESUS  a press about every 0.5 seconds; your own buttons go straight
--             through as always
--   HELIX     a wilder crowd, a press about every 0.22 seconds, AND your own
--             buttons go into the queue like a TPP viewer's: one of your
--             inputs reaches the game every 0.6 seconds, fed in among the
--             chaos
--
-- Who is in the crowd (per speed, see SPEEDS):
--   followers  copy one of your own inputs, a little late (in HELIX they
--              pull from the same queue your 0.6 s commands come from)
--   noise      any button the screen allows; the mix of directions to the
--              rest swings every 10 s between 8:2, 7:3 and 6:4
--   herders    repeat the last button the crowd sent
--   trolls     START, or the griefer's favourite direction of the moment
--
-- Every 10 s the crowd's size re-rolls too (busier, normal, quieter), and
-- with EVENTS on, now and then something happens: a START riot, a lull, or
-- a streak of one direction (a 1 in 4 chance every 15 s on BRDJESUS, 1 in 3
-- every 10 s on HELIX).  None of the gaps are exact; they average out.
--
-- What the followers remember of you: every press, in order, except that
-- mashing one button only counts twice in a row, and never your START+
-- SELECT off switch.  Each remembered input is used once.  It carries over
-- from screen to screen, but is forgotten when you open a settings screen
-- or turn the mod off.
--
-- A direction is held for 12 frames, so it takes a real step in the
-- overworld; A, B, START and SELECT for 2, long enough to register.
-- Never two of its own presses at once: the next one waits for the last to
-- finish (your own START+SELECT, below, is read apart from all of this).
--
-- It starts once you are back in the overworld: turning it on in a menu
-- never sends chaos into that menu.  It goes nearly everywhere you can --
-- lib/context.lua has the short list of where it never presses (settings,
-- the Mod Manager, a mod's own START row, link play, the title), the one
-- button it never presses on RELEASE in the PC (A), and the two it never
-- presses on SAVE or the save screen's YES (A and START).  Every crowd
-- press, followers' included, goes through those rules.
--
-- HOLD START+SELECT together for a quarter of a second to stop it, at any
-- speed, HELIX included: read from your raw buttons (keyboard, pad, or two
-- fingers on the touch screen), ahead of HELIX's queue.  PRAISE HELIX goes
-- back to OFF (saved) until you turn it on again.  The mod's own presses
-- never count.
--
-- Presses go through mod.input, the engine's tool-input API: each one is
-- this mod's own input source ("mod:praise_helix:N"), which is how a press
-- of yours and a press of the mod's are always told apart.
--
-- Low-end hardware: when OFF the hook does nothing but count; when ON a
-- frame costs a few table reads.  Screens are only looked at when a press
-- is due or the screen on top changes, and HELIX's input view is only in
-- place while HELIX is actually running.

local mod = ...

local V = { mod = mod }

-- ------- which generation is this boot?

local function generation()
  local n = tonumber(mod.generation)
  if n == 1 or n == 2 or n == 3 then return n end
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if ok and GameVersion and type(GameVersion.generation) == "function" then
    local g = GameVersion.generation()
    if g == 2 or g == 3 then return g end
  end
  return 1
end
V.generation = generation()

-- ------- options

-- the first row only holds text: how to stop it (START+SELECT)
local hintRow = { key = "stop_hint", label = "STRTSLCT", type = "choice", default = "",
  choices = { { "", "" } } }

mod.options:define({
  hintRow,
  { key = "speed", label = "PRAISE HELIX", type = "choice", default = "off",
    choices = { { "OFF", "off" }, { "BRDJESUS", "brdjesus" }, { "HELIX", "helix" } } },
  { key = "events", label = "EVENTS", type = "choice", default = "on",
    choices = { { "ON", "on" }, { "OFF", "off" } } },
  { key = "battles", label = "BATTLES", type = "choice", default = "trainers",
    choices = { { "OFF", "off" }, { "TRAINERS", "trainers" }, { "ALL", "all" } } },
})

function V.option(key, default)
  local ok, v = pcall(mod.options.get, mod.options, key)
  if ok and v ~= nil then return v end
  return default
end

local modules = {}
function V.require(name)
  local hit = modules[name]
  if hit ~= nil then return hit end
  local source = mod:read("lib/" .. name .. ".lua")
  if not source then error("praise_helix: lib/" .. name .. ".lua is missing -- reinstall the mod", 0) end
  local chunk, err = load(source, "=praise_helix/lib/" .. name)
  if not chunk then error("praise_helix: lib/" .. name .. " did not compile: " .. tostring(err), 0) end
  local value = chunk(V)
  modules[name] = value
  return value
end

local Context = V.require("context")

-- ------- timing (the game runs a fixed 60 logic steps a second)

-- Per speed:
--   gap       the average steps between crowd presses (0.5 s / 0.22 s)
--   wander    how far the crowd's size swings each 10 s (rate x 1-w, 1, 1+w)
--   roles     who the crowd is, by share: followers / noise / herders / trolls
--   event     the chance that an event starts (EVENTS on), rolled every
--   eventEvery  steps (15 s on BRDJESUS, 10 s on HELIX)
--   queue     HELIX: your own buttons go through the 0.6 s queue
local SPEEDS = {
  brdjesus = { gap = 30, wander = 0.5, event = 0.25, eventEvery = 900,
    roles = { follow = 45, noise = 35, herd = 13, troll = 7 } },
  -- HELIX's gap is set to 11 so that, with every button in play, presses
  -- land about 0.22 s apart: a direction's 12-frame hold stretches the
  -- busiest moments, and this makes up for it
  helix = { gap = 11, wander = 0.6, event = 1 / 3, eventEvery = 600, queue = true,
    roles = { follow = 40, noise = 40, herd = 11, troll = 9 } },
}
local ROLE_ORDER = { "follow", "noise", "herd", "troll" }
-- HELIX: one of the player's own inputs gets through every 0.6 s
local PLAYER_EVERY = 36
-- a direction is held this many steps: long enough that it takes one step
-- in the overworld (a one-tick tap only turns the player on the Game Boy
-- games), short of the fastest interval
local HOLD = 12
-- A, B, START and SELECT are held this many steps instead: long enough to
-- register with the game (a single tick risked being too short), short
-- enough that it still reads as one press, not a hold of its own
local HOLD_FACE = 2
-- START+SELECT must be held together this long to stop it (a quarter
-- second: a deliberate press, not a brush of the thumb)
local STOP_HOLD = 15
-- every 10 s: the direction mix swings, the crowd re-sizes, an event may start
local BEAT = 600
local MIX_EVERY = BEAT
local MIXES = { 0.8, 0.7, 0.6 }
local MIX_WEIGHTS = { 3, 4, 4 }          -- 8:2 a little less often
local SPEED_RECHECK = 60                 -- the option is re-read once a second
-- what the followers remember of you
local MEMORY_SIZE = 8                    -- the last 8 inputs, oldest dropped
local RUN_CAP = 2                        -- mashing one button counts twice
-- events
local RIOT_PRESSES = { 3, 6 }            -- START, START, START...
local RIOT_GAP = 10                      -- steps between riot presses
local STREAK_PRESSES = { 3, 5 }          -- one direction, again and again
local LULL_STEPS = 240                   -- 4 s ...
local LULL_FACTOR = 3                    -- ... at a third of the rate

local BUTTONS = { "up", "down", "left", "right", "a", "b", "start", "select" }
local NBUTTONS = #BUTTONS

local random = (love and love.math and love.math.random) or math.random

local function log(level, msg)
  local l = mod.log
  if type(l) == "table" and type(l[level]) == "function" then
    pcall(l[level], l, "%s", msg)
  end
end

-- On a gamepad, holding SELECT and pressing A or B is the recomp's own
-- shortcut for COLORS / TILT (src/core/Game.lua's padPressedBody): it reads
-- Input:isDown("select") the instant a REAL A/B press arrives, and that
-- can't tell your hold from a press this mod made.  okGamepadMap guards the
-- one place that matters.
local okGamepadMap, GamepadMap = pcall(require, "src.core.GamepadMap")

-- ------- turning it off (START+SELECT)

-- The value the Mod Manager's own options page would write, the same four
-- places: the loader's live table (what mod.options:get reads), the save's
-- options (the next boot), the options file, and mod.options_changed.
local function setSpeed(game, v)
  local id = mod.id
  local loader = game and game.mods
  if type(loader) == "table" then
    loader.modOptions = loader.modOptions or {}
    loader.modOptions[id] = loader.modOptions[id] or {}
    loader.modOptions[id].speed = v
    local save = game.save
    if type(save) == "table" and type(save.options) == "table" then
      save.options.modOptions = save.options.modOptions or {}
      save.options.modOptions[id] = save.options.modOptions[id] or {}
      save.options.modOptions[id].speed = v
    end
    if type(game.writeOptions) == "function" then pcall(game.writeOptions, game) end
    local events = loader.events
    if type(events) == "table" and type(events.emit) == "function" then
      pcall(events.emit, events, "mod.options_changed", { mod = id, key = "speed", value = v })
    end
    return true
  end
  return false
end

-- ------- the driver

local state = {
  speed = "off", cfg = nil, recheck = 0, tick = 0,
  armed = false,            -- false until the player is back in the overworld
  top = nil,                -- what was on top at the last step
  timer = 0, gap = 0, held = nil, heldFor = 0,
  playerTimer = 0, playerHeld = nil, playerHeldFor = 0,
  stopFor = 0, forcedOff = false,
  mix = 0.7, beat = 0, eventBeat = 0, crowd = 1, griefer = "down", owed = 0,
  event = nil, lullLeft = 0, lastSent = nil,
  memory = {}, runBtn = nil, runLen = 0,
  ourEdge = {}, oursHeld = {}, lastQueued = {}, queued = {},
  view = false, hookTicked = false, missed = 0,
}

local PREFIX = "mod:" .. tostring(mod.id) .. ":"
local PREFIX_LEN = #PREFIX

-- is anything but this mod holding `btn`?  (keyboard, pad, touch, another mod)
local function physical(input, btn)
  local src = input.sources
  src = src and src[btn]
  if not src then return false end
  for source in pairs(src) do
    if type(source) ~= "string" or source:sub(1, PREFIX_LEN) ~= PREFIX then return true end
  end
  return false
end

local function let(slot)
  local h = state[slot]
  if h then
    pcall(mod.input.release, mod.input, h.token)
    local n = (state.oursHeld[h.btn] or 1) - 1
    state.oursHeld[h.btn] = n > 0 and n or nil
    state[slot] = nil
  end
  state[slot .. "For"] = 0
end

local function release()
  let("held")
  let("playerHeld")
end

local function pressInto(slot, game, btn)
  local ok, token = pcall(mod.input.press, mod.input, game, btn)
  if ok and token then
    state[slot] = { btn = btn, token = token }
    state[slot .. "For"] = 0
    state.ourEdge[btn] = state.tick
    state.oursHeld[btn] = (state.oursHeld[btn] or 0) + 1
    return true
  end
  return false
end

-- The d-pad is held for HOLD steps (so a direction takes a real step in
-- the overworld); A, B, START and SELECT for the shorter HOLD_FACE instead.
local HOLD_BUTTONS = { up = true, down = true, left = true, right = true }
local function holdFor(btn) return HOLD_BUTTONS[btn] and HOLD or HOLD_FACE end

-- The soft-reset chord is A+B+START+SELECT.  A random press must never be
-- the button that completes it (you holding three of them while the mod
-- happens to press the fourth would reset the game).
local CHORD = { a = true, b = true, start = true, select = true }
local function completesChord(input, btn)
  if not CHORD[btn] then return false end
  local st = input.state
  if type(st) ~= "table" then return false end
  for b in pairs(CHORD) do
    if b ~= btn and not st[b] then return false end
  end
  return true
end

-- per allowed-set, its directions and its other buttons, built once
local groups = setmetatable({}, { __mode = "k" })
local function groupsOf(allowed)
  local g = groups[allowed]
  if not g then
    local moves, others = {}, {}
    for i = 1, NBUTTONS do
      local b = BUTTONS[i]
      if allowed[b] then
        if i <= 4 then moves[#moves + 1] = b else others[#others + 1] = b end
      end
    end
    g = { moves, others }
    groups[allowed] = g
  end
  return g
end

local function pick(allowed, share)
  local g = groupsOf(allowed)
  local moves, others = g[1], g[2]
  local group
  if #moves > 0 and #others > 0 then
    group = (random() < (share or state.mix)) and moves or others
  else
    group = (#moves > 0) and moves or others
  end
  if #group == 0 then return nil end
  return group[random(1, #group)]
end

local function newMix()
  local total = 0
  for i = 1, #MIX_WEIGHTS do total = total + MIX_WEIGHTS[i] end
  local r = random() * total
  for i = 1, #MIXES do
    r = r - MIX_WEIGHTS[i]
    if r < 0 then return MIXES[i] end
  end
  return MIXES[#MIXES]
end

-- ------- the crowd

-- who presses next: a role drawn by share; skipFollow leaves the followers
-- out (nothing of yours to copy) and shares the rest out by weight
local function pickRole(cfg, skipFollow)
  local roles = cfg.roles
  local total = 0
  for i = 1, #ROLE_ORDER do
    local k = ROLE_ORDER[i]
    if not (skipFollow and k == "follow") then total = total + roles[k] end
  end
  local r = random() * total
  for i = 1, #ROLE_ORDER do
    local k = ROLE_ORDER[i]
    if not (skipFollow and k == "follow") then
      r = r - roles[k]
      if r < 0 then return k end
    end
  end
  return "noise"
end

-- the crowd's size for the next 10 s: busier, normal or quieter
local function newCrowd(cfg)
  local w = cfg.wander
  local k = random(1, 3)
  return (k == 1 and 1 - w) or (k == 2 and 1) or (1 + w)
end

local MOVES = { "up", "down", "left", "right" }

local function startEvent(kind)
  if kind == "lull" then
    state.lullLeft = LULL_STEPS
  elseif kind == "riot" then
    state.event = { kind = "riot", left = random(RIOT_PRESSES[1], RIOT_PRESSES[2]) }
  elseif kind == "streak" then
    state.event = { kind = "streak", left = random(STREAK_PRESSES[1], STREAK_PRESSES[2]) }
  end
end

local EVENT_KINDS = { "riot", "lull", "streak" }

-- the 10-second beat: the mix, the crowd's size, the griefer, maybe an event
local function onBeat(cfg)
  state.owed = 0
  state.mix = newMix()
  state.crowd = newCrowd(cfg)
  state.griefer = MOVES[random(1, 4)]
end

-- the event roll, on its own beat (15 s on BRDJESUS, 10 s on HELIX)
local function onEventBeat(cfg)
  if not state.event and state.lullLeft <= 0 and V.option("events", "on") == "on"
      and random() < cfg.event then
    startEvent(EVENT_KINDS[random(1, #EVENT_KINDS)])
  end
end

-- steps until the next crowd press (after one of `btn`, or none)
-- A press can't start until the last one is let go, so a gap is never
-- shorter than the last press's hold (13 steps after a direction).  At
-- HELIX's 0.2 s that floor is above the average itself; the steps lost to it
-- are owed and taken off the next gaps (down to their own floor), so short
-- gaps after A/B/START/SELECT win it back and the rate still averages out.
-- What's owed is wiped every 10 s, so a busy stretch never borrows from a
-- quiet one.
local function nextGap(cfg, btn)
  local min = (btn and holdFor(btn) or 0) + 1
  if state.event and state.event.kind == "riot" then
    return math.max(RIOT_GAP, min)
  end
  -- the crowd's size scales the rate (a busier crowd presses more often),
  -- so the gaps still average out to the speed over the busy and quiet
  -- stretches alike
  local g = cfg.gap / state.crowd * (0.5 + random())
  if state.lullLeft > 0 then g = g * LULL_FACTOR end
  g = g - state.owed
  local rounded = math.floor(g + 0.5)
  if rounded < min then
    state.owed = min - g
    return min
  end
  state.owed = 0
  return rounded
end

-- the followers' memory of you
local function forget()
  local m = state.memory
  for i = #m, 1, -1 do m[i] = nil end
  state.runBtn, state.runLen = nil, 0
end

local function remember(input, b)
  -- never your START+SELECT off switch
  if (b == "start" and physical(input, "select")) or (b == "select" and physical(input, "start")) then
    return
  end
  -- mashing one button counts twice, no more
  if b == state.runBtn then
    if state.runLen >= RUN_CAP then return end
    state.runLen = state.runLen + 1
  else
    state.runBtn, state.runLen = b, 1
  end
  local m = state.memory
  if #m >= MEMORY_SIZE then table.remove(m, 1) end
  m[#m + 1] = b
end

-- the oldest remembered input the screen allows (it is used up); entries
-- the screen does not allow stay for a screen that does
local function takeMemory(allowed, input)
  local m = state.memory
  for i = 1, #m do
    local b = m[i]
    if allowed[b] and not completesChord(input, b) then
      table.remove(m, i)
      return b
    end
  end
  return nil
end

-- the button a crowd member presses here
local function crowdButton(cfg, allowed, input)
  local role = pickRole(cfg)
  if role == "follow" then
    local b = takeMemory(allowed, input)
    if b then return b end
    role = pickRole(cfg, true)        -- nothing of yours to copy here
  end
  if role == "herd" then
    local b = state.lastSent
    if b and allowed[b] then return b end
  elseif role == "troll" then
    if random() < 0.5 and allowed.start then return "start" end
    if allowed[state.griefer] then return state.griefer end
  end
  return pick(allowed)
end

-- ------- HELIX: the game sees only this mod's presses
--
-- While HELIX runs, the input's readers -- isDown and wasPressed, which
-- every screen of all three generations reads buttons through -- answer
-- from this mod's own presses only.  The player's buttons are collected
-- raw and one is fed back in every 0.6 seconds.  The view is only in place
-- while HELIX is running (off, paused, any other speed: the engine's own
-- functions, untouched), and it takes itself out if this mod stops
-- stepping for any reason: Input:step notices two steps with no tick from
-- the hook below.

local saved = nil   -- { input, isDown, wasPressed, isTouchDown, step }

local function removeView()
  state.view = false
  local s = saved
  if not s then return end
  saved = nil
  local input = s.input
  if input.isDown == s.myDown then input.isDown = s.isDown end
  if input.wasPressed == s.myPressed then input.wasPressed = s.wasPressed end
  if s.myTouch and input.isTouchDown == s.myTouch then input.isTouchDown = s.isTouchDown end
  if input.step == s.myStep then input.step = s.step end
end

local function installView(input)
  if saved then
    if saved.input == input then state.view = true return end
    removeView()
  end
  local realDown, realPressed, realTouch, realStep =
    input.isDown, input.wasPressed, input.isTouchDown, input.step
  if type(realDown) ~= "function" or type(realPressed) ~= "function"
      or type(realStep) ~= "function" then
    return
  end
  local oursHeld, ourEdge = state.oursHeld, state.ourEdge
  local s = { input = input, isDown = realDown, wasPressed = realPressed,
    isTouchDown = realTouch, step = realStep }
  s.myDown = function(self, btn)
    if state.view then return oursHeld[btn] ~= nil end
    return realDown(self, btn)
  end
  s.myPressed = function(self, btn)
    -- an edge this mod made this step -- even on a button you hold, which
    -- the real input would not count as new
    if state.view then return ourEdge[btn] == state.tick end
    return realPressed(self, btn)
  end
  if type(realTouch) == "function" then
    s.myTouch = function(self, btn)
      if state.view then return false end
      return realTouch(self, btn)
    end
  end
  s.myStep = function(self, ...)
    if state.hookTicked then
      state.hookTicked, state.missed = false, 0
    else
      state.missed = state.missed + 1
      if state.missed >= 2 then removeView() end
    end
    return realStep(self, ...)
  end
  input.isDown, input.wasPressed, input.step = s.myDown, s.myPressed, s.myStep
  if s.myTouch then input.isTouchDown = s.myTouch end
  saved = s
  state.view, state.missed = true, 0
end

-- ------- the player's own presses, for the followers (and HELIX's queue)
--
-- Read raw, never through the view: the queue holds this step's keyboard
-- and touch presses (also a tap pressed and let go inside one step); the
-- last step's `pressed` adds the gamepad's, which Input:step polls itself.
-- This mod's own presses are left out by their edge ledger.
local function recordPlayer(input)
  local queued, last = state.queued, state.lastQueued
  for i = 1, NBUTTONS do queued[BUTTONS[i]] = nil end
  local q = input.pressQueue
  if q then
    for i = 1, #q do
      local b = q[i]
      queued[b] = true
      remember(input, b)
    end
  end
  local pressed = input.pressed
  if pressed then
    local prev = state.tick - 1
    for i = 1, NBUTTONS do
      local b = BUTTONS[i]
      if pressed[b] and not last[b] and state.ourEdge[b] ~= prev then remember(input, b) end
    end
  end
  state.queued, state.lastQueued = last, queued
end

-- ------- arming, pausing, stopping

local function disarm()
  release()
  removeView()
  forget()
  state.armed = false
  state.timer, state.playerTimer = 0, 0
  state.event, state.lullLeft = nil, 0
end

local function stop(game)
  disarm()
  state.stopFor = 0
  if not setSpeed(game, "off") then state.forcedOff = true end
  state.speed, state.cfg = "off", nil
  log("info", "START+SELECT held: Praise Helix turned OFF")
end

local function readSpeed()
  local v = V.option("speed", "off")
  if v ~= state.speed then
    state.speed = v
    disarm()          -- any change waits for the overworld again
  end
  -- (an old DIGRAT setting, or anything unknown, reads as OFF)
  state.cfg = (not state.forcedOff) and SPEEDS[v] or nil
end

local function step(game)
  local input = game and game.input
  if type(input) ~= "table" then return end

  -- OFF: count down to the once-a-second option check, nothing else
  state.recheck = state.recheck - 1
  if state.recheck <= 0 then
    state.recheck = SPEED_RECHECK
    readSpeed()
  end
  local cfg = state.cfg
  if not cfg then
    if state.held or state.playerHeld or saved then disarm() end
    return
  end

  state.tick = state.tick + 1
  state.hookTicked = true

  -- START+SELECT held together: the off switch, ahead of everything
  local st = input.state
  if st and st.start and st.select and physical(input, "start") and physical(input, "select") then
    state.stopFor = state.stopFor + 1
    if state.stopFor == 1 then
      -- the START (or SELECT) that began it is not something to copy
      local m = state.memory
      while m[#m] == "start" or m[#m] == "select" do m[#m] = nil end
    end
    if state.stopFor >= STOP_HOLD then stop(game) return end
  else
    state.stopFor = 0
  end

  -- what is on top; the screens are only looked at when this changes
  local top = Context.top(game)
  if top ~= state.top then
    local prev = state.top
    state.top = top
    if state.armed and Context.locks(game, prev, top) then
      disarm()
    elseif state.held then
      local allowed = Context.allowed(game)
      if not (allowed and allowed[state.held.btn]) then let("held") end
    end
  end

  if not state.armed then
    -- waits for the plain overworld: turning it on in a menu, or a pause
    -- for a screen it stays out of, never sends chaos into the menus
    if not Context.overworld(game, top) then return end
    state.armed = true
    state.timer, state.playerTimer, state.beat, state.eventBeat = 0, 0, 0, 0
    state.mix, state.crowd, state.griefer = newMix(), newCrowd(cfg), MOVES[random(1, 4)]
    state.owed = 0
    state.gap = nextGap(cfg, nil)
  end

  -- the 10-second beat
  state.beat = state.beat + 1
  if state.beat >= BEAT then state.beat = 0; onBeat(cfg) end
  state.eventBeat = state.eventBeat + 1
  if state.eventBeat >= cfg.eventEvery then state.eventBeat = 0; onEventBeat(cfg) end
  if state.lullLeft > 0 then state.lullLeft = state.lullLeft - 1 end

  -- your own presses, for the followers
  recordPlayer(input)

  -- HELIX: the player's queue
  if cfg.queue then
    if not state.view then installView(input) end
    if state.playerHeld then
      state.playerHeldFor = state.playerHeldFor + 1
      if state.playerHeldFor >= holdFor(state.playerHeld.btn) then let("playerHeld") end
    end
    state.playerTimer = state.playerTimer + 1
    -- never a second press while one is still going: our own presses never
    -- overlap each other, the chaos's included, only your own START+SELECT
    -- is read apart from all of this (see above)
    if state.playerTimer >= PLAYER_EVERY and not state.playerHeld and not state.held
        and state.stopFor == 0 then
      state.playerTimer = 0
      -- the oldest of your inputs still waiting (the followers draw from
      -- the same queue), or the button you are holding
      local cmd = table.remove(state.memory, 1)
      if not cmd then
        for i = 1, NBUTTONS do
          if physical(input, BUTTONS[i]) then cmd = BUTTONS[i] break end
        end
      end
      -- the player's own command: theirs to steer, so it is not limited
      if cmd and not completesChord(input, cmd) then pressInto("playerHeld", game, cmd) end
    end
  elseif saved then
    removeView()
    let("playerHeld")
    state.playerTimer = 0
  end

  -- the crowd
  local held = state.held
  if held then
    state.heldFor = state.heldFor + 1
    if state.heldFor >= holdFor(held.btn) or completesChord(input, held.btn) then let("held") end
  end
  state.timer = state.timer + 1
  -- never a second press while one is still going (yours in HELIX's queue
  -- included)
  if state.timer < state.gap or state.held or state.playerHeld then return end
  state.timer = 0
  -- while you are holding the off switch, nothing new is pressed (START+
  -- SELECT is half of the soft-reset chord; the rest stays yours)
  if state.stopFor > 0 then state.gap = nextGap(cfg, nil) return end
  local allowed = Context.allowed(game)
  local btn
  local ev = state.event
  if ev then
    ev.left = ev.left - 1
    if ev.left <= 0 then state.event = nil end
    if ev.kind == "riot" then
      btn = allowed and allowed.start and "start" or nil
    else
      if not ev.btn and allowed then
        local moves = groupsOf(allowed)[1]
        if #moves > 0 then ev.btn = moves[random(1, #moves)] end
      end
      btn = ev.btn and allowed and allowed[ev.btn] and ev.btn or nil
    end
  elseif allowed then
    btn = crowdButton(cfg, allowed, input)
  end
  if btn and allowed and not completesChord(input, btn) and pressInto("held", game, btn) then
    state.lastSent = btn
  end
  -- (an event's riot gaps run from here too)
  state.gap = nextGap(cfg, btn)
end

mod.hooks:wrap("input.step", function(next, game, dt)
  local ok, err = pcall(step, game)
  if not ok then
    log("warn", tostring(err))
    pcall(disarm)
  end
  return next(game, dt)
end)

-- Never let our own held SELECT -- the chaos, or your own command echoed
-- back in HELIX -- complete the recomp's SELECT+A (COLORS) or SELECT+B
-- (TILT) shortcut on a button you pressed for an ordinary reason.  Our
-- SELECT steps aside for just that one real press and comes straight back
-- after, so your own SELECT, genuinely held, still works as it always did.
-- SELECT is genuinely held for HOLD_FACE steps (0.13.1), so this is load-
-- bearing, not a backstop: that short window is exactly when a real press
-- could otherwise land on top of ours.
local function liftOurSelect()
  local lifted
  for _, slot in ipairs({ "held", "playerHeld" }) do
    local h = state[slot]
    if h and h.btn == "select" then
      pcall(mod.input.release, mod.input, h.token)
      lifted = lifted or {}
      lifted[#lifted + 1] = slot
    end
  end
  return lifted
end

local function restoreOurSelect(game, lifted)
  if not lifted then return end
  for _, slot in ipairs(lifted) do
    local ok, token = pcall(mod.input.press, mod.input, game, "select")
    if ok and token then
      state[slot] = { btn = "select", token = token }
    else
      state[slot] = nil
      state[slot .. "For"] = 0
    end
  end
end

-- Only a real A/B/X/Y/leftshoulder press can complete that chord (see
-- GamepadMap.displayChordDigit); if GamepadMap can't be read, guard every
-- press rather than none.
local function chordCapable(button)
  if not okGamepadMap then return true end
  local ok, digit = pcall(GamepadMap.displayChordDigit, button)
  return ok and digit ~= nil
end

mod.hooks:wrap("input.gamepad", function(next, game, ctx)
  if type(ctx) == "table" and ctx.phase == "pressed" and chordCapable(ctx.button) then
    local lifted = liftOurSelect()
    local ok, a, b, c = pcall(next, game, ctx)
    restoreOurSelect(game, lifted)
    if not ok then error(a, 0) end
    return a, b, c
  end
  return next(game, ctx)
end)

mod.events:on("mod.options_changed", function(ev)
  if type(ev) == "table" and ev.mod == mod.id and ev.key == "speed" then
    if ev.value ~= "off" then state.forcedOff = false end
    state.recheck = 0          -- read on the next step
  end
end)

readSpeed()

mod.exports.version = "1.0"
mod.exports._internal = { V = V, context = Context, state = state, step = step,
  setSpeed = setSpeed, SPEEDS = SPEEDS, HOLD = HOLD, PLAYER_EVERY = PLAYER_EVERY,
  STOP_HOLD = STOP_HOLD, MIX_EVERY = MIX_EVERY, BEAT = BEAT, MIXES = MIXES,
  MIX_WEIGHTS = MIX_WEIGHTS, MEMORY_SIZE = MEMORY_SIZE, RUN_CAP = RUN_CAP,
  RIOT_PRESSES = RIOT_PRESSES, RIOT_GAP = RIOT_GAP, STREAK_PRESSES = STREAK_PRESSES,
  LULL_STEPS = LULL_STEPS, LULL_FACTOR = LULL_FACTOR,
  pick = pick, newMix = newMix, pickRole = pickRole, newCrowd = newCrowd,
  startEvent = startEvent, onBeat = onBeat, onEventBeat = onEventBeat, nextGap = nextGap, crowdButton = crowdButton,
  hintRow = hintRow, HOLD_BUTTONS = HOLD_BUTTONS,
  HOLD_FACE = HOLD_FACE, holdFor = holdFor, pressInto = pressInto, let = let,
  viewInstalled = function() return saved ~= nil end }
