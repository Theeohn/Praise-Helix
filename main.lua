-- Praise Helix: Twitch Plays Pokemon chaos, on top of your own buttons.
--
-- With PRAISE HELIX on, a random button -- UP, DOWN, LEFT, RIGHT, A, B, START
-- or SELECT -- is pressed for you on a timer while you keep playing.
--
--   DIGRAT    one press every 0.9 seconds
--   BRDJESUS  one press every 0.5 seconds
--   HELIX     one press every 0.3 seconds, AND your own buttons go into the
--             queue like a TPP viewer's: the game only gets one of your
--             inputs every 0.9 seconds (the last button you pressed, or the
--             one you are holding), fed in among the chaos
--
-- The mix of directions to everything else swings every 10 seconds between
-- 8:2, 7:3 and 6:4 (8:2 a little less often than the other two).
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
-- presses on SAVE or the save screen's YES (A and START).
--
-- HOLD START+SELECT together for a quarter of a second to stop it, at any
-- speed, HELIX included: read from your raw buttons (keyboard, pad, or two
-- fingers on the touch screen), ahead of HELIX's queue.  PRAISE HELIX goes back
-- to OFF (saved) until you turn it on again.  The mod's own presses never
-- count.
--
-- Presses go through mod.input, the engine's tool-input API: each one is
-- this mod's own input source ("mod:praise_helix:N"), which is how a press of
-- yours and a press of the mod's are always told apart.
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
    choices = { { "OFF", "off" }, { "DIGRAT", "digrat" }, { "BRDJESUS", "brdjesus" },
      { "HELIX", "helix" } } },
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

local STEPS = { digrat = 54, brdjesus = 30, helix = 18 }
-- HELIX: one of the player's own inputs gets through every 0.9 s
local PLAYER_EVERY = 54
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
-- the mix swings every 10 s; directions' share, and how often each comes up
local MIX_EVERY = 600
local MIXES = { 0.8, 0.7, 0.6 }
local MIX_WEIGHTS = { 3, 4, 4 }          -- 8:2 a little less often
local SPEED_RECHECK = 60                 -- the option is re-read once a second

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
  speed = "off", every = nil, recheck = 0, tick = 0,
  armed = false,            -- false until the player is back in the overworld
  top = nil,                -- what was on top at the last step
  timer = 0, held = nil, heldFor = 0,
  playerTimer = 0, playerHeld = nil, playerHeldFor = 0, lastSeen = nil,
  stopFor = 0, forcedOff = false,
  mix = 0.7, mixTimer = 0,
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

-- ------- HELIX: the game sees only this mod's presses
--
-- While HELIX runs, the input's readers -- isDown and wasPressed, which
-- every screen of all three generations reads buttons through -- answer
-- from this mod's own presses only.  The player's buttons are collected
-- raw and one is fed back in every 0.9 seconds.  The view is only in place
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

-- ------- the player's own presses, for HELIX's queue
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
      state.lastSeen = b
    end
  end
  local pressed = input.pressed
  if pressed then
    local prev = state.tick - 1
    for i = 1, NBUTTONS do
      local b = BUTTONS[i]
      if pressed[b] and not last[b] and state.ourEdge[b] ~= prev then state.lastSeen = b end
    end
  end
  state.queued, state.lastQueued = last, queued
end

-- ------- arming, pausing, stopping

local function disarm()
  release()
  removeView()
  state.armed = false
  state.timer, state.playerTimer, state.lastSeen = 0, 0, nil
end

local function stop(game)
  disarm()
  state.stopFor = 0
  if not setSpeed(game, "off") then state.forcedOff = true end
  state.speed, state.every = "off", nil
  log("info", "START+SELECT held: Praise Helix turned OFF")
end

local function readSpeed()
  local v = V.option("speed", "off")
  if v ~= state.speed then
    state.speed = v
    disarm()          -- any change waits for the overworld again
  end
  state.every = (not state.forcedOff) and STEPS[v] or nil
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
  local every = state.every
  if not every then
    if state.held or state.playerHeld or saved then disarm() end
    return
  end

  state.tick = state.tick + 1
  state.hookTicked = true

  -- START+SELECT held together: the off switch, ahead of everything
  local st = input.state
  if st and st.start and st.select and physical(input, "start") and physical(input, "select") then
    state.stopFor = state.stopFor + 1
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
    state.timer, state.playerTimer, state.lastSeen = 0, 0, nil
    state.mix, state.mixTimer = newMix(), 0
  end

  -- the mix swings every 10 seconds
  state.mixTimer = state.mixTimer + 1
  if state.mixTimer >= MIX_EVERY then state.mixTimer = 0; state.mix = newMix() end

  -- HELIX: the player's queue
  if every == STEPS.helix then
    if not state.view then installView(input) end
    recordPlayer(input)
    if state.playerHeld then
      state.playerHeldFor = state.playerHeldFor + 1
      if state.playerHeldFor >= holdFor(state.playerHeld.btn) then let("playerHeld") end
    end
    state.playerTimer = state.playerTimer + 1
    -- never a second press while one is still going: our own presses never
    -- overlap each other, the chaos's included, only your own START+SELECT
    -- is read apart from all of this (see the top of step())
    if state.playerTimer >= PLAYER_EVERY and not state.playerHeld and not state.held
        and state.stopFor == 0 then
      state.playerTimer = 0
      local cmd = state.lastSeen
      if not cmd then
        for i = 1, NBUTTONS do
          if physical(input, BUTTONS[i]) then cmd = BUTTONS[i] break end
        end
      end
      state.lastSeen = nil
      -- the player's own command: theirs to steer, so it is not limited
      if cmd and not completesChord(input, cmd) then pressInto("playerHeld", game, cmd) end
    end
  elseif saved then
    removeView()
    let("playerHeld")
    state.playerTimer, state.lastSeen = 0, nil
  end

  -- the chaos
  local held = state.held
  if held then
    state.heldFor = state.heldFor + 1
    if state.heldFor >= holdFor(held.btn) or completesChord(input, held.btn) then let("held") end
  end
  state.timer = state.timer + 1
  -- never a second press while one is still going (yours in HELIX's queue
  -- included)
  if state.timer < every or state.held or state.playerHeld then return end
  state.timer = 0
  -- while you are holding the off switch, nothing new is pressed (START+
  -- SELECT is half of the soft-reset chord; the rest stays yours)
  if state.stopFor > 0 then return end
  local allowed = Context.allowed(game)
  if not allowed then return end
  local btn = pick(allowed)
  if btn and not completesChord(input, btn) then pressInto("held", game, btn) end
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

mod.exports.version = "0.13.2"
mod.exports._internal = { V = V, context = Context, state = state, step = step,
  setSpeed = setSpeed, STEPS = STEPS, HOLD = HOLD, PLAYER_EVERY = PLAYER_EVERY,
  STOP_HOLD = STOP_HOLD, MIX_EVERY = MIX_EVERY, MIXES = MIXES, MIX_WEIGHTS = MIX_WEIGHTS,
  pick = pick, newMix = newMix, hintRow = hintRow, HOLD_BUTTONS = HOLD_BUTTONS,
  HOLD_FACE = HOLD_FACE, holdFor = holdFor, pressInto = pressInto, let = let,
  viewInstalled = function() return saved ~= nil end }
