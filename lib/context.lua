-- Praise Helix / context: where the chaos may press, and what.
--
-- This is Twitch Plays Pokemon, so the chaos goes almost everywhere the
-- player can: the overworld, every START menu screen (POKEDEX, POKEMON,
-- BAG, the trainer card, SAVE) and everything under them, the PC, shops,
-- the POKEMON CENTER, the Day-Care, yes/no questions, berry trees, battles
-- (see the BATTLES option) -- including screens a mod has rebuilt (a new
-- Pokedex, bag or party menu keeps its place, so it keeps the chaos).
--
-- M.allowed(game) answers, at the moment of a press, with one of:
--
--   M.ALL    every button
--   M.NO_A   every button but A
--   nil      no random press at all
--
-- Never pressed into (nil), and the chaos stays paused until you are back
-- in the overworld once you go there (see M.locks):
--
--   the Mod Manager, every options / settings screen (the game's, the
--   recomp's -- controls, touch layout, palettes, shaders -- and any mod's),
--   and anything opened from them
--   any START menu row other than the game's own (a row a mod adds, and
--   OPTION, MODS and QUIT) and anything opened from it
--   the title screen, intro and main menu, link cable / wireless / Union
--   Room / trades over link, the battle arena
--
-- Never A (M.NO_A): RELEASE, anywhere in any PC.  A random A is never
-- pressed while a highlighted row says RELEASE, nor at any point of a
-- release (choosing the POKEMON, the "are you sure?", the goodbye), so a
-- POKEMON can only ever be released by you.  On the START menu A is only
-- pressed on the game's own safe rows.
--
-- Everything here is read only when a press is about to happen, or when
-- the screen on top changes; nothing runs on the frames in between.

local V = ...

local M = {}

local function set(...)
  local s = {}
  for _, b in ipairs({ ... }) do s[b] = true end
  return s
end

M.ALL = set("up", "down", "left", "right", "a", "b", "start", "select")
M.NO_A = set("up", "down", "left", "right", "b", "start", "select")

local find, lower = string.find, string.lower

-- engine modules, required once and kept (they are singletons); a module
-- that is not there is remembered as missing, so it is never asked twice
local cache = {}
local loaded = setmetatable({}, { __index = function(_, name)
  local hit = cache[name]
  if hit == nil then
    local ok, m = pcall(require, name)
    hit = (ok and type(m) == "table") and m or false
    cache[name] = hit
  end
  return hit or nil
end })

-- which battles take random input: "off" | "trainers" | "all"
local function battleAllowed(isTrainer)
  local mode = V.option("battles", "trainers")
  if mode == "all" then return true end
  if mode == "trainers" then return isTrainer == true end
  return false
end

-- ---------------------------------------------------------- names

-- A screen whose id names one of these is never pressed into: settings of
-- every kind, the manager, link play, the boot.  Checked by pattern so a
-- mod's "FooSettings" screen counts too.  Memoised per id.
local DENY_PATTERNS = {
  "option", "setting", "manager", "binding", "control", "touch", "palette",
  "shader", "skin", "quarantine", "link", "union", "wireless", "arena",
  "title", "mainmenu", "intro", "splash", "oakspeech", "initclock", "clock",
  "mystery", "direct_corner", "minigame_lobby", "pin_entry", "gamefreak",
  "copyright", "newgame", "new_game", "gender",
}
local denyMemo = {}
local function deniedId(id)
  if type(id) ~= "string" then return false end
  local hit = denyMemo[id]
  if hit == nil then
    hit = false
    local s = lower(id)
    for i = 1, #DENY_PATTERNS do
      if find(s, DENY_PATTERNS[i], 1, true) then hit = true break end
    end
    denyMemo[id] = hit
  end
  return hit
end

local function mentionsRelease(v)
  return type(v) == "string" and find(lower(v), "releas", 1, true) ~= nil
end

-- the row a menu-like screen has highlighted, whatever widget it is
local function highlighted(s)
  local rows = s.items or s.rows or s.entries
  if type(rows) ~= "table" then return nil end
  local i = s.index or s.cursor or s.selected
  if i == nil and type(s.list) == "table" then i = s.list.index end
  local row = rows[tonumber(i) or 1]
  return type(row) == "table" and row or nil
end

local function rowReleases(row)
  return row ~= nil and (mentionsRelease(row.label) or mentionsRelease(row.id)
    or mentionsRelease(row.value) or mentionsRelease(row.action))
end

-- does this screen show a release in progress, or have RELEASE highlighted?
local function screenReleases(s)
  if type(s) ~= "table" then return false end
  if mentionsRelease(s.kind) or mentionsRelease(s.message) or mentionsRelease(s.prompt)
      or mentionsRelease(s.question) or mentionsRelease(s.listPrompt)
      or mentionsRelease(s.footer) or mentionsRelease(s.mode) then
    return true
  end
  if rowReleases(highlighted(s)) then return true end
  -- Gold/Crystal's box screen keeps its WITHDRAW/STATS/RELEASE rows apart
  if s.phase == "submenu" and type(s.submenuRows) == "function" then
    local ok, rows = pcall(s.submenuRows, s)
    if ok and type(rows) == "table" and rowReleases(rows[s.submenuIndex or 1]) then
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------- START menus

local GEN1_SAFE = { "POKéDEX", "POKéMON", "ITEM", "SAVE" }
local function gen1StartSafe(game, s)
  local row = highlighted(s)
  local label = row and row.label
  if label == nil then return false end
  local Strings = loaded["src.core.Strings"]
  for i = 1, #GEN1_SAFE do
    local k = GEN1_SAFE[i]
    local ok, text = true, k
    if Strings then ok, text = pcall(Strings, k) end
    if ok and label == text then return true end
  end
  local player = game.save and game.save.player
  return label == ((player and player.name) or "RED")
end

local GEN2_SAFE = { pokedex = true, pokemon = true, pack = true, pokegear = true,
  status = true, save = true }
local function gen2StartSafe(s)
  local rows, list = s.items, s.list
  local row = type(rows) == "table" and rows[(list and list.index) or 1]
  return row ~= nil and GEN2_SAFE[row.value] == true
end

local GEN3_SAFE = { pokedex = true, pokemon = true, bag = true, pyramid_bag = true,
  pokenav = true, trainer = true, save = true, exit = true, retire = true }
local function gen3StartSafe()
  local SM = loaded["src.ui.game3.start_menu"]
  local e = SM and type(SM.ENTRIES) == "table" and SM.ENTRIES[SM.cursor or 1]
  return e ~= nil and GEN3_SAFE[e.id] == true
end

-- ---------------------------------------------------------- Gen 1 / Gen 2

local function states(game)
  local st = game.stack
  return type(st) == "table" and type(st.states) == "table" and st.states or nil
end

local function isStart(gen, s)
  local id = s.screenId
  return (gen == 1 and id == "StartMenu") or (gen == 2 and id == "Gen2StartMenu")
end

local function startSafe(gen, game, s)
  if gen == 1 then return gen1StartSafe(game, s) end
  return gen2StartSafe(s)
end

local function deniedScreen(s)
  return type(s) == "table" and (s.isModOptions == true or deniedId(s.screenId))
end

local function stackAllowed(gen, game)
  if game.linkSession or game.linkNet then return nil end
  local list = states(game)
  if gen == 2 then
    if game.phase ~= "play" or type(game.world) ~= "table" then return nil end
  elseif not list then
    return nil
  end
  local n = list and #list or 0
  local inGame = (gen == 2)
  local noA = false
  for i = 1, n do
    local s = list[i]
    if type(s) == "table" then
      if s.isOverworld then inGame = true end
      if deniedScreen(s) then return nil end
      local id = s.screenId
      local mt = getmetatable(s)
      local B1 = gen == 1 and loaded["src.battle.BattleState"]
      if (B1 and mt == B1) or id == "BattleState" then
        if s.demo or s.oakDemo then return nil end
        if not battleAllowed(s.kind == "trainer") then return nil end
      elseif id == "Gen2BattleState" then
        local core = s.battle
        if core and core.linkBattle then return nil end
        if not battleAllowed(core ~= nil and core.trainer ~= nil) then return nil end
      elseif isStart(gen, s) then
        if gen == 2 and s.phase ~= nil and i == n then return nil end  -- QUIT's confirm
        if i < n and not startSafe(gen, game, s) then return nil end
        if i == n and not startSafe(gen, game, s) then noA = true end
      end
      if not noA and screenReleases(s) then noA = true end
    end
  end
  if not inGame then return nil end
  if gen == 2 and n == 0 and game.world.battleActive then return nil end
  return noA and M.NO_A or M.ALL
end

-- ---------------------------------------------------------- Gen 3

local function gen3Allowed(game)
  local Battle = loaded["src.core.game3.battle"]
  if Battle and Battle.isActive and Battle.isActive() then
    local st = Battle._st
    if not st or st.link then return nil end
    if not battleAllowed(not st.wild) then return nil end
  elseif game.phase ~= "field" or not game.session then
    return nil
  end
  local Stack = loaded["src.ui.game3.stack"]
  local layers = Stack and Stack._layers
  local noA = false
  if type(layers) == "table" then
    local n = #layers
    for i = 1, n do
      local layer = layers[i]
      local id = layer.id
      if id == "mod_manager" or deniedId(id) then return nil end
      local state = type(layer.mod) == "table" and layer.mod.state
      if type(state) == "table" then
        if state.isModOptions == true or deniedId(state.screenId) then return nil end
        if screenReleases(state) then noA = true end
      end
      if id == "start" then
        local SM = loaded["src.ui.game3.start_menu"]
        if SM and (SM._tutorial or SM._confirmExit or SM._prompt) then return nil end
        if not gen3StartSafe() then
          if i < n then return nil end
          noA = true
        end
      end
    end
  end
  local Release = loaded["src.ui.game3.release_seq"]
  if Release and Release.active then noA = true end
  local Box = loaded["src.ui.game3.box_storage_ui"]
  if Box and Box.open and Box.mode == "action_menu" then
    local actions = Box._activeActions
    if type(actions) == "table" and mentionsRelease(actions[Box.actionCursor or 1]) then
      noA = true
    end
  end
  return noA and M.NO_A or M.ALL
end

-- ---------------------------------------------------------- the API

function M.allowed(game)
  if type(game) ~= "table" then return nil end
  local gen = V.generation
  local ok, s
  if gen == 3 then ok, s = pcall(gen3Allowed, game)
  else ok, s = pcall(stackAllowed, gen, game) end
  if ok then return s end
  return nil
end

-- What is on top right now, as cheaply as it can be read: the chaos only
-- looks closer when this changes.  false = nothing (the field itself).
function M.top(game)
  if V.generation == 3 then
    local Stack = loaded["src.ui.game3.stack"]
    local layers = Stack and Stack._layers
    return (type(layers) == "table" and layers[#layers]) or false
  end
  local list = states(game)
  return (list and list[#list]) or false
end

-- Is the player back in the plain overworld, no menu up?  (the chaos only
-- starts -- and restarts after a pause -- from here)
function M.overworld(game, top)
  local gen = V.generation
  if gen == 3 then
    if top then return false end
    local Battle = loaded["src.core.game3.battle"]
    if Battle and Battle.isActive and Battle.isActive() then return false end
    return game.phase == "field" and game.session ~= nil
  elseif gen == 2 then
    return top == false and game.phase == "play" and type(game.world) == "table"
      and not game.world.battleActive
  end
  return type(top) == "table" and top.isOverworld == true
end

-- The screen on top changed from `prev` to `cur`.  True means: pause the
-- chaos until the overworld -- the player went somewhere it must not
-- follow (a settings screen, the manager, a START row that is not the
-- game's own and whatever it opened).
function M.locks(game, prev, cur)
  local gen = V.generation
  local ok, hit = pcall(function()
    if gen == 3 then
      if type(cur) == "table" then
        if cur.id == "mod_manager" or deniedId(cur.id) then return true end
        local state = type(cur.mod) == "table" and cur.mod.state
        if type(state) == "table" and (state.isModOptions == true or deniedId(state.screenId)) then
          return true
        end
      end
      return type(prev) == "table" and prev.id == "start" and not gen3StartSafe()
    end
    if deniedScreen(cur) then return true end
    return type(prev) == "table" and isStart(gen, prev) and not startSafe(gen, game, prev)
  end)
  return ok and hit == true
end

M._deniedId = deniedId
M._screenReleases = screenReleases

return M
