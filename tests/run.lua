-- Praise Helix headless suite.
--
--   cp -r . <engine>/mods/praise_helix && cd <engine> && luajit mods/praise_helix/tests/run.lua
--
-- Loads the mod through the engine's own SDK on each generation and checks:
--   * where the chaos goes (nearly everywhere) and where it never does
--     (settings, the Mod Manager, a mod's START row and what it opens, link
--     play, the title), against the engine's REAL screens where they build
--   * that A is never pressed on RELEASE, or during a release, in any PC
--   * the driver through the engine's REAL Input: speeds, the swinging
--     direction mix, the start-in-the-overworld delay, START+SELECT to stop (keys,
--     pad and touch; never the mod's own presses), HELIX's 0.9 s queue and
--     its self-removing view, the soft-reset guard, and how little it does
--     per frame.

package.path = "./?.lua;./?/init.lua;" .. package.path
love = love or require("tests.love_stub")
require("src.core.Logger").warn = function() end

local Sdk = require("tests.modkit.sdk")

local MOD = "mods/praise_helix"
local passed, failed = 0, 0
local function check(cond, label)
  if cond then passed = passed + 1 else
    failed = failed + 1
    print("FAIL  " .. label)
  end
end
local function eq(a, b, label)
  check(a == b, label .. "  (got " .. tostring(a) .. ", want " .. tostring(b) .. ")")
end

local BUTTONS = { "up", "down", "left", "right", "a", "b", "start", "select" }
local function keys(s)
  if s == nil then return "-" end
  local out = {}
  for _, b in ipairs(BUTTONS) do if s[b] then out[#out + 1] = b end end
  return table.concat(out, ",")
end

local ALL = "up,down,left,right,a,b,start,select"
local NO_A = "up,down,left,right,b,start,select"
local NO_A_START = "up,down,left,right,b,select"

local function boot(gen)
  local opts = { generation = gen }
  if gen == 3 then opts.data = Sdk.gen3Data() end
  local r = Sdk.loadMod(MOD, opts)
  for _, e in ipairs(r.errors or {}) do print("LOAD ERROR", gen, e) end
  return r, r.loader.exports.praise_helix
end

local function stackOf(...)
  local states = { ... }
  return { states = states, top = function() return states[#states] end,
    push = function(_, s) states[#states + 1] = s end, pop = function() return table.remove(states) end }
end

for gen = 1, 3 do
  local r, ex = boot(gen)
  check(ex ~= nil, "gen" .. gen .. " loads")
  if ex then
    local I = ex._internal
    local Ctx = I.context
    local tag = "gen" .. gen .. " "
    local function setOpt(key, v)
      r.loader.modOptions.praise_helix = r.loader.modOptions.praise_helix or {}
      r.loader.modOptions.praise_helix[key] = v
      I.state.recheck = 0
    end
    setOpt("battles", "trainers")
    local function verdict(game) return keys(Ctx.allowed(game)) end

    -- ---- the options page
    local schema = r.loader.optionSchemas.praise_helix
    eq(schema and schema[1] and schema[1].key, "stop_hint", tag .. "the first options row is the stop hint")
    eq(schema[1].label, "STRTSLCT", tag .. "it reads STRTSLCT")
    eq(#(schema[1].choices or {}), 1, tag .. "it only holds text (one fixed value)")
    eq(schema[2].key, "speed", tag .. "then PRAISE HELIX")
    local speeds = {}
    for _, c in ipairs(schema[2].choices) do speeds[#speeds + 1] = c[1] end
    eq(table.concat(speeds, " "), "OFF BRDJESUS HELIX", tag .. "speeds (DIGRAT is gone)")
    eq(schema[3].key, "events", tag .. "then EVENTS")
    local evs = {}
    for _, c in ipairs(schema[3].choices) do evs[#evs + 1] = c[1] end
    eq(table.concat(evs, " "), "ON OFF", tag .. "EVENTS: ON / OFF")
    eq(schema[3].default, "on", tag .. "EVENTS is ON by default")

    if gen == 1 then
      local TextBox = require("src.render.TextBox")
      local ChoiceBox = require("src.ui.ChoiceBox")
      local Menu = require("src.ui.Menu")
      local ListMenu = require("src.ui.ListMenu")
      local BattleState = require("src.battle.BattleState")
      local Strings = require("src.core.Strings")
      local save = { player = { name = "ASH" } }
      local function g(...) return { save = save, stack = stackOf(...) } end
      local over = { isOverworld = true }
      eq(verdict(g(over)), ALL, tag .. "overworld: every button")
      eq(verdict(g(over, setmetatable({}, TextBox))), ALL, tag .. "dialogue: every button")
      eq(verdict(g(over, setmetatable({}, ChoiceBox))), ALL, tag .. "an NPC's YES/NO: every button")
      for _, id in ipairs({ "PokedexMenu", "DexEntryMenu", "PartyMenu", "BagMenu", "TrainerCard",
          "SummaryMenu", "BoxMenu", "PlayerPC", "ShopMenu", "NamingScreen", "EvolutionState",
          "MoveLearnMenu", "QuantityBox", "TownMap", "SlotMachine", "TradeAnim", "SomeModScreen" }) do
        eq(verdict(g(over, { screenId = id })), ALL, tag .. id .. ": every button")
      end
      eq(verdict(g(over, { screenId = "PartyMenu" }, setmetatable({ items = { { label = "STATS" } }, index = 1 }, Menu))),
        ALL, tag .. "a party submenu: every button")
      eq(verdict(g(over, { qolCompScreen = true })), ALL, tag .. "a mod's rebuilt screen: every button")
      -- never
      for _, id in ipairs({ "OptionsMenu", "ManagerState", "BindingsMenu", "TouchControlsEditor",
          "ShaderFXScreen", "PaletteScreen", "SkinStudio", "QuarantineReport", "ArenaState",
          "QolSettingsPage" }) do
        eq(verdict(g(over, { screenId = id })), "-", tag .. id .. ": nothing")
        eq(verdict(g(over, { screenId = id }, setmetatable({}, Menu))), "-",
          tag .. "anything opened from " .. id .. ": nothing")
      end
      eq(verdict(g(over, { isModOptions = true })), "-", tag .. "a mod's options screen: nothing")
      eq(verdict(g({ screenId = "TitleState" })), "-", tag .. "the title: nothing")
      eq(verdict(g(setmetatable({}, Menu))), "-", tag .. "no game running (a menu with no overworld): nothing")
      eq(verdict({ save = save, stack = stackOf(over), linkSession = {} }), "-", tag .. "never during a link")
      -- the START menu, by row
      local rows = { Strings("POKéDEX"), Strings("POKéMON"), Strings("ITEM"), "ASH",
        Strings("SAVE"), Strings("OPTION"), "MODS", "GAMESHARK", Strings("QUIT") }
      local want = { ALL, ALL, ALL, ALL, NO_A_START, NO_A, NO_A, NO_A, NO_A }
      local above = { ALL, ALL, ALL, ALL, NO_A_START, "-", "-", "-", "-" }
      local menu = setmetatable({ screenId = "StartMenu", items = {}, index = 1 }, Menu)
      for i, l in ipairs(rows) do menu.items[i] = { label = l } end
      for i, l in ipairs(rows) do
        menu.index = i
        eq(verdict(g(over, menu)), want[i], tag .. "START menu on " .. l)
        eq(verdict(g(over, menu, { screenId = "SomeScreen" })), above[i],
          tag .. "a screen opened from START's " .. l)
      end
      -- the save: no A or START on YES, anywhere in it
      menu.index = 5
      local panel = {}
      eq(verdict(g(over, menu, panel)), NO_A_START, tag .. "save panel: no A or START")
      eq(verdict(g(over, menu, panel, setmetatable({}, TextBox))), NO_A_START,
        tag .. "\"Would you like to SAVE?\": no A or START")
      local yn = setmetatable({ index = 1 }, ChoiceBox)
      eq(verdict(g(over, menu, panel, setmetatable({}, TextBox), yn)), NO_A_START, tag .. "save YES/NO on YES: no A or START")
      yn.index = 2
      eq(verdict(g(over, menu, panel, setmetatable({}, TextBox), yn)), ALL, tag .. "save YES/NO on NO: every button")
      yn.index = 1
      eq(verdict(g(over, setmetatable({}, ChoiceBox))), ALL, tag .. "an NPC's YES/NO on YES: still every button")
      -- RELEASE in the PC
      local pc = setmetatable({ items = { { label = Strings("WITHDRAW <PK><MN>") },
        { label = Strings("DEPOSIT <PK><MN>") }, { label = Strings("RELEASE <PK><MN>") },
        { label = Strings("CHANGE BOX") }, { label = Strings("SEE YA!") } }, index = 1 }, Menu)
      eq(verdict(g(over, pc)), ALL, tag .. "Bill's PC on WITHDRAW: every button")
      pc.index = 3
      eq(verdict(g(over, pc)), NO_A, tag .. "Bill's PC on RELEASE: never A")
      local list = setmetatable({ kind = "pc_box_release", items = { { label = "PIDGEY" } }, index = 1 }, ListMenu)
      eq(verdict(g(over, pc, list)), NO_A, tag .. "choosing who to release: never A")
      eq(verdict(g(over, pc, list, setmetatable({}, TextBox), setmetatable({}, ChoiceBox))), NO_A,
        tag .. "the release YES/NO: never A")
      pc.index = 1
      local wd = setmetatable({ kind = "pc_box_withdraw", items = { { label = "PIDGEY" } }, index = 1 }, ListMenu)
      eq(verdict(g(over, pc, wd)), ALL, tag .. "choosing who to withdraw: every button")
      eq(verdict(g(over, setmetatable({ items = { { label = "RELEASE" } }, index = 1 }, Menu))), NO_A,
        tag .. "a mod's own PC with RELEASE highlighted: never A")
      -- battles
      local function battle(kind, extra)
        local b = setmetatable({ kind = kind, phase = "menu", menuIndex = 1 }, BattleState)
        for k, v in pairs(extra or {}) do b[k] = v end
        return b
      end
      eq(verdict(g(over, battle("trainer"))), ALL, tag .. "trainer battle: every button")
      eq(verdict(g(over, battle("trainer"), { screenId = "PartyMenu" })), ALL, tag .. "its party menu too")
      eq(verdict(g(over, battle("wild"))), "-", tag .. "BATTLES TRAINERS: wild battles untouched")
      eq(verdict(g(over, battle("wild"), { screenId = "PartyMenu" })), "-", tag .. "nor their party menu")
      setOpt("battles", "all")
      eq(verdict(g(over, battle("wild"))), ALL, tag .. "BATTLES ALL: wild too")
      eq(verdict(g(over, battle("wild", { safari = {} }))), ALL, tag .. "BATTLES ALL: the Safari Zone too")
      eq(verdict(g(over, battle("wild", { oakDemo = true }))), "-", tag .. "never the catching demo")
      setOpt("battles", "off")
      eq(verdict(g(over, battle("trainer"))), "-", tag .. "BATTLES OFF: no battle")
      setOpt("battles", "trainers")
      -- pausing: what it will not follow you into
      menu.index = 6
      check(Ctx.locks(g(over), menu, { screenId = "OptionsMenu" }), tag .. "START > OPTION pauses it")
      menu.index = 7
      check(Ctx.locks(g(over), menu, { screenId = "ManagerState" }), tag .. "START > MODS pauses it")
      menu.index = 8
      check(Ctx.locks(g(over), menu, { qolCompScreen = true }), tag .. "a mod's START row pauses it")
      menu.index = 2
      check(not Ctx.locks(g(over), menu, { screenId = "PartyMenu" }), tag .. "START > POKEMON does not")
      check(Ctx.locks(g(over), over, { screenId = "OptionsMenu" }), tag .. "opening any settings pauses it")
      check(not Ctx.locks(g(over), over, { screenId = "BoxMenu" }), tag .. "the PC does not")
      check(Ctx.overworld(g(over), over), tag .. "the overworld is the overworld")
      check(not Ctx.overworld(g(over, menu), menu), tag .. "the START menu is not")
    elseif gen == 2 then
      local TextBox = require("src.render.TextBox")
      local function g(w, ...) return { phase = "play", world = w or {}, stack = stackOf(...) } end
      eq(verdict(g()), ALL, tag .. "overworld: every button")
      eq(verdict(g({ textbox = true })), ALL, tag .. "dialogue: every button")
      eq(verdict(g({ textbox = true, choicebox = true })), ALL, tag .. "an NPC's YES/NO: every button")
      eq(verdict({ phase = "boot", world = {}, stack = stackOf() }), "-", tag .. "title screen: nothing")
      for _, id in ipairs({ "Gen2PokedexMenu", "Gen2PartyMenu", "Gen2PackMenu", "Gen2TrainerCard",
          "Gen2PcMenu", "Gen2BoxMenu", "Gen2CenterPcMenu", "Gen2MartMenu", "Gen2NamingScreen",
          "Gen2EvolutionAnim", "Gen2DayCareMenu", "Gen2MoveDeleter", "Gen2ScriptMenu", "Gen2Pokegear",
          "Gen2TradeMenu", "Gen2BankOfMom" }) do
        eq(verdict(g(nil, { screenId = id })), ALL, tag .. id .. ": every button")
      end
      eq(verdict(g(nil, setmetatable({}, TextBox))), ALL, tag .. "a text box: every button")
      for _, id in ipairs({ "Gen2OptionsMenu", "ManagerState", "Gen2MainMenu", "Gen2TitleState",
          "Gen2InitClock", "Gen2ArenaState", "BindingsMenu" }) do
        eq(verdict(g(nil, { screenId = id })), "-", tag .. id .. ": nothing")
      end
      local rows = { "pokedex", "pokemon", "pack", "pokegear", "status", "save", "option", "mods", "quit" }
      local want = { ALL, ALL, ALL, ALL, ALL, NO_A_START, NO_A, NO_A, NO_A }
      local sm = { screenId = "Gen2StartMenu", items = {}, list = { index = 1 } }
      for i, v in ipairs(rows) do sm.items[i] = { value = v, label = v:upper() } end
      sm.items[#sm.items + 1] = { label = "GAMESHARK", onSelect = function() end }
      for i, v in ipairs(rows) do
        sm.list.index = i
        eq(verdict(g(nil, sm)), want[i], tag .. "START menu on " .. v)
      end
      sm.list.index = #sm.items
      eq(verdict(g(nil, sm)), NO_A, tag .. "START menu on a mod's row: no A")
      eq(verdict(g(nil, sm, { screenId = "ModScreen" })), "-", tag .. "anything a mod's row opened: nothing")
      check(Ctx.locks(g(), sm, { screenId = "ModScreen" }), tag .. "and opening it pauses the chaos")
      sm.list.index = 2
      check(not Ctx.locks(g(), sm, { screenId = "Gen2PartyMenu" }), tag .. "START > POKEMON does not pause it")
      sm.phase = "confirm"
      eq(verdict(g(nil, sm)), "-", tag .. "QUIT's confirm: nothing")
      sm.phase = nil
      -- the save screen: no A or START while YES is highlighted
      local sv = { screenId = "Gen2SaveMenu", phase = "confirm", choice = 1 }
      eq(verdict(g(nil, sv)), NO_A_START, tag .. "save screen on YES: no A or START")
      sv.choice = 2
      eq(verdict(g(nil, sv)), ALL, tag .. "save screen on NO: every button")
      sv.phase, sv.choice = "overwrite", 1
      eq(verdict(g(nil, sv)), NO_A_START, tag .. "\"overwrite?\" on YES: no A or START")
      local Save2 = require("src.ui.gen2.SaveMenu")
      local okS, real = pcall(Save2.new, { data = r.data, save = { player = {}, options = {} } },
        { save = { player = {}, options = {} }, writer = function() return true end })
      if okS and type(real) == "table" then
        real.screenId = real.screenId or "Gen2SaveMenu"
        eq(real.choice, 1, tag .. "(the real save screen opens on YES)")
        eq(verdict(g(nil, real)), NO_A_START, tag .. "real save screen on YES: no A or START")
        real.choice = 2
        eq(verdict(g(nil, real)), ALL, tag .. "real save screen on NO: every button")
      else
        print("note: gen2 SaveMenu did not build headless: " .. tostring(real))
      end
      -- RELEASE in the PC
      local box = { screenId = "Gen2BoxMenu", phase = "submenu", submenuIndex = 1,
        submenuRows = function() return { { id = "WITHDRAW" }, { id = "STATS" }, { id = "RELEASE" }, { id = "CANCEL" } } end }
      eq(verdict(g(nil, box)), ALL, tag .. "the box submenu on WITHDRAW: every button")
      box.submenuIndex = 3
      eq(verdict(g(nil, box)), NO_A, tag .. "the box submenu on RELEASE: never A")
      box.message = "Release PKMN?"
      eq(verdict(g(nil, box, { screenId = "ChoiceBox" })), NO_A, tag .. "the release YES/NO: never A")
      box.phase, box.message = nil, nil
      eq(verdict(g(nil, box)), ALL, tag .. "back on the box list: every button")
      -- battles
      local function bs(trainer, extra)
        local b = { screenId = "Gen2BattleState", phase = "menu", menuIndex = 1,
          battle = { trainer = trainer and {} or nil } }
        for k, v in pairs(extra or {}) do b[k] = v end
        return b
      end
      eq(verdict(g(nil, bs(true))), ALL, tag .. "trainer battle: every button")
      eq(verdict(g(nil, bs(false))), "-", tag .. "BATTLES TRAINERS: wild battles untouched")
      setOpt("battles", "all")
      eq(verdict(g(nil, bs(false, { contest = true }))), ALL, tag .. "BATTLES ALL: the Bug-Catching Contest too")
      eq(verdict(g(nil, bs(true, { battle = { trainer = {}, linkBattle = true } }))), "-", tag .. "never a link battle")
      setOpt("battles", "trainers")
      check(Ctx.overworld(g(), false), tag .. "the overworld is the overworld")
      check(not Ctx.overworld(g(nil, sm), sm), tag .. "the START menu is not")
    else
      local Stack = require("src.ui.game3.stack")
      local SM = require("src.ui.game3.start_menu")
      local Battle = require("src.core.game3.battle")
      local Release = require("src.ui.game3.release_seq")
      local Box = require("src.ui.game3.box_storage_ui")
      local game = { phase = "field", session = {} }
      local saved = { Stack._layers, SM.ENTRIES, SM.cursor, Battle._active, Battle._st, Box.open, Box.mode,
        Box._activeActions, Box.actionCursor }
      Stack._layers = {}
      eq(verdict(game), ALL, tag .. "field: every button")
      eq(verdict({ phase = "boot", session = {} }), "-", tag .. "title screen: nothing")
      for _, id in ipairs({ "pokedex", "party", "bag", "trainer", "summary", "box_storage", "pc_menu",
          "item_pc", "shop", "naming", "evolution_scene", "move_relearner", "berry_pouch",
          "rs_daycare_party", "region_map", "modui:7" }) do
        Stack._layers = {}; Stack.push(id, {})
        eq(verdict(game), ALL, tag .. id .. ": every button")
      end
      for _, id in ipairs({ "option", "mod_manager", "controls", "union_room", "link_trade",
          "wireless_status", "direct_corner", "minigame_lobby", "pin_entry" }) do
        Stack._layers = {}; Stack.push(id, {})
        eq(verdict(game), "-", tag .. id .. ": nothing")
      end
      Stack._layers = {}; Stack.push("modui:9", { state = { isModOptions = true } })
      eq(verdict(game), "-", tag .. "a mod's options screen: nothing")
      Stack._layers = {}
      Stack.push("start", {})
      local rows = { "pokedex", "pokemon", "bag", "pokenav", "trainer", "save", "option", "mods", "exit" }
      local want = { ALL, ALL, ALL, ALL, ALL, NO_A_START, NO_A, NO_A, ALL }
      SM.ENTRIES = {}
      for i, id in ipairs(rows) do SM.ENTRIES[i] = { id = id, label = id:upper() } end
      SM.ENTRIES[#SM.ENTRIES + 1] = { label = "GAMESHARK", onSelect = function() end }
      for i, id in ipairs(rows) do
        SM.cursor = i
        eq(verdict(game), want[i], tag .. "START menu on " .. id)
      end
      SM.cursor = #SM.ENTRIES
      eq(verdict(game), NO_A, tag .. "START menu on a mod's row: no A")
      Stack.push("modui:3", {})
      eq(verdict(game), "-", tag .. "anything a mod's row opened: nothing")
      local startLayer = Stack._layers[1]
      check(Ctx.locks(game, startLayer, Stack._layers[2]), tag .. "and opening it pauses the chaos")
      SM.cursor = 2
      check(not Ctx.locks(game, startLayer, { id = "party" }), tag .. "START > POKEMON does not pause it")
      check(Ctx.locks(game, false, { id = "option" }), tag .. "opening OPTION pauses it")
      Stack._layers = {}
      -- the save screen: no A or START while YES is highlighted
      local SaveMenu3 = require("src.ui.game3.save_menu")
      local oldCursor = SaveMenu3.cursor
      Stack.push("save", SaveMenu3)
      SaveMenu3.cursor = 1
      eq(verdict(game), NO_A_START, tag .. "save screen on YES: no A or START")
      SaveMenu3.cursor = 2
      eq(verdict(game), ALL, tag .. "save screen on NO: every button")
      SaveMenu3.cursor = oldCursor
      Stack._layers = {}
      -- RELEASE in the PC
      Stack.push("box_storage", {})
      Box.open, Box.mode, Box._activeActions, Box.actionCursor = true, "action_menu",
        { "WITHDRAW", "SUMMARY", "RELEASE", "CANCEL" }, 1
      eq(verdict(game), ALL, tag .. "the box action menu on WITHDRAW: every button")
      Box.actionCursor = 3
      eq(verdict(game), NO_A, tag .. "the box action menu on RELEASE: never A")
      Box.actionCursor, Box.mode = 1, "browse"
      local wasActive = Release.active
      Release.active = true
      eq(verdict(game), NO_A, tag .. "the release YES/NO and goodbye: never A")
      Release.active = wasActive
      Box.open = false
      Stack._layers = {}
      -- battles
      Battle._active = true
      Battle._st = { wild = false }
      eq(verdict(game), ALL, tag .. "trainer battle: every button")
      Battle._st = { wild = true }
      eq(verdict(game), "-", tag .. "BATTLES TRAINERS: wild battles untouched")
      setOpt("battles", "all")
      Battle._st = { wild = true, safari = true }
      eq(verdict(game), ALL, tag .. "BATTLES ALL: the Safari Zone too")
      Battle._st = { wild = false, link = true }
      eq(verdict(game), "-", tag .. "never a link battle")
      setOpt("battles", "trainers")
      check(not Ctx.overworld(game, false), tag .. "a battle is not the overworld")
      Battle._active = saved[4]
      Battle._st = saved[5]
      check(Ctx.overworld(game, false), tag .. "the field is the overworld")
      Stack._layers, SM.ENTRIES, SM.cursor = saved[1], saved[2], saved[3]
      Box.open, Box.mode, Box._activeActions, Box.actionCursor = saved[6], saved[7], saved[8], saved[9]
    end

    -- ---- the REAL screens, built by the engine
    if gen == 1 then
      local T = require("tests.modkit")
      local Data = T.fixtures.fresh()
      require("src.render.Font").load(Data)
      local SaveData = require("src.core.SaveData")
      local Screens = require("src.ui.Screens")
      local save = SaveData.newGame()
      save.player.name = "ASH"
      save.flags = save.flags or {}
      save.flags.EVENT_GOT_POKEDEX = true
      local over = { isOverworld = true }
      local g = { data = Data, save = save, modStatus = { available = { {} } }, stack = stackOf(over) }
      local ok, err = pcall(Screens.push, g, "StartMenu")
      check(ok, tag .. "the real START menu builds (" .. tostring(err) .. ")")
      local menu = g.stack.states[#g.stack.states]
      if ok and menu then
        local Strings = require("src.core.Strings")
        local aRows, saveV = {}, nil
        for i, row in ipairs(menu.items) do
          menu.index = i
          local v = keys(Ctx.allowed(g))
          if v == ALL then aRows[#aRows + 1] = tostring(row.label) end
          if row.label == Strings("SAVE") then saveV = v end
        end
        eq(#aRows, 4, tag .. "real START menu: A on POKEDEX, POKEMON, ITEM and the card ("
          .. table.concat(aRows, "/") .. ")")
        eq(saveV, NO_A_START, tag .. "real START menu: SAVE gets no A and no START")
        -- the real save flow: SAVE's own panel and prompt, then its YES/NO
        local saveIndex
        for i, row in ipairs(menu.items) do if row.label == Strings("SAVE") then saveIndex = i end end
        menu.index = saveIndex
        local okS, errS = pcall(menu.items[saveIndex].onSelect)
        check(okS, tag .. "the real SAVE opens (" .. tostring(errS) .. ")")
        local panel = g.stack.states[#g.stack.states]
        eq(keys(Ctx.allowed(g)), NO_A_START, tag .. "real save panel: no A or START")
        if okS and panel and panel.openPrompt then
          pcall(panel.openPrompt)
          eq(keys(Ctx.allowed(g)), NO_A_START, tag .. "real \"Would you like to SAVE?\": no A or START")
          local ChoiceBox = require("src.ui.ChoiceBox")
          local yn = ChoiceBox.new(g, function() end)
          g.stack:push(yn)
          eq(yn.index, 1, tag .. "(the real YES/NO opens on YES)")
          eq(keys(Ctx.allowed(g)), NO_A_START, tag .. "real save YES/NO on YES: no A or START")
          yn.index = 2
          eq(keys(Ctx.allowed(g)), ALL, tag .. "real save YES/NO on NO: every button")
        end
      end
      g.stack = stackOf(over)
      local ok2, box = pcall(function() return require("src.ui.BoxMenu").new(g) end)
      check(ok2 and box, tag .. "the real Bill's PC builds (" .. tostring(box) .. ")")
      if ok2 and box then
        local releaseRows = 0
        for i, row in ipairs(box.items) do
          box.index = i
          local v = keys(Ctx.allowed({ data = Data, save = save, stack = stackOf(over, box) }))
          if v == NO_A then releaseRows = releaseRows + 1
            check(tostring(row.label):upper():find("RELEASE") ~= nil, tag .. "real PC: the no-A row is RELEASE")
          else
            eq(v, ALL, tag .. "real PC row " .. tostring(row.label) .. ": every button")
          end
        end
        eq(releaseRows, 1, tag .. "real PC: exactly one row is never pressed with A")
      end
    elseif gen == 2 then
      local Start2 = require("src.ui.gen2.StartMenu")
      r.data.text = setmetatable({}, { __index = function(_, k)
        local n = tostring(k):match("^StartMenu%.(.-)String$")
        return n and n:upper() or "TXT"
      end })
      local g = { data = r.data, modStatus = { available = { {} } },
        save = { player = { name = "KRIS" }, party = { {} }, options = {} }, phase = "play", world = {} }
      local ok, m = pcall(Start2.new, g, { save = g.save,
        unlocked = { mods = true, pokedex = true, party = true, pack = true, pokegear = true } })
      check(ok, tag .. "the real START menu builds")
      if ok then
        m.screenId = "Gen2StartMenu"
        g.stack = stackOf(m)
        local aRows = {}
        for i, row in ipairs(m.items) do
          m.list.index = i
          if keys(Ctx.allowed(g)) == ALL then aRows[#aRows + 1] = tostring(row.value) end
        end
        eq(table.concat(aRows, ","), "pokedex,pokemon,pack,pokegear,status",
          tag .. "real START menu: A on the game's own rows, never SAVE/OPTION/MODS/QUIT")
      end
    end

    -- ---- the driver, through the engine's REAL Input
    -- (the screen answers are the test's: the real ones are checked above)
    local Input = require("src.core.Input")
    local realCtx = { allowed = Ctx.allowed, top = Ctx.top, overworld = Ctx.overworld, locks = Ctx.locks }
    local origDown, origPressed, origStep = Input.isDown, Input.wasPressed, Input.step
    local current, topv, ow, lockv = nil, false, true, false
    local calls = { allowed = 0, top = 0 }
    Ctx.allowed = function() calls.allowed = calls.allowed + 1 return current end
    Ctx.top = function() calls.top = calls.top + 1 return topv end
    Ctx.overworld = function() return ow end
    Ctx.locks = function() return lockv end
    local function reset()
      if Input.reset then Input:reset() end
      local s = I.state
      s.timer, s.heldFor, s.held, s.forcedOff, s.armed, s.stopFor = 0, 0, nil, false, false, 0
      s.playerTimer, s.playerHeld, s.top = 0, nil, false
      s.event, s.lullLeft, s.lastSent = nil, 0, nil
      for i = #s.memory, 1, -1 do s.memory[i] = nil end
      s.runBtn, s.runLen = nil, 0
      for k in pairs(s.oursHeld) do s.oursHeld[k] = nil end
      current, topv, ow, lockv = nil, false, true, false
    end
    local function newGame()
      reset()
      return { input = Input, mods = r.loader, save = { options = {} }, writeOptions = function() end }
    end
    -- one logic tick, the way every Game does it: input.step, then Input:step;
    -- edgesSeen gets every edge the game sees, modLog every press the mod
    -- starts (the crowd's, and your queued HELIX commands)
    local edgesSeen, modLog = {}, {}
    local function tick(game)
      local h, p = I.state.held, I.state.playerHeld
      I.step(game)
      Input:step()
      for _, b in ipairs(BUTTONS) do
        if Input:wasPressed(b) then edgesSeen[#edgesSeen + 1] = b end
      end
      local h2, p2 = I.state.held, I.state.playerHeld
      if h2 and h2 ~= h then modLog[#modLog + 1] = { t = I.state.tick, btn = h2.btn, who = "crowd" } end
      if p2 and p2 ~= p then modLog[#modLog + 1] = { t = I.state.tick, btn = p2.btn, who = "you" } end
    end
    local function run(speed, steps, game)
      setOpt("speed", speed)
      edgesSeen, modLog = {}, {}
      for _ = 1, steps do tick(game) end
      return edgesSeen
    end
    local function speedNow() return r.loader.modOptions.praise_helix.speed end
    local function hold(btn, source) Input:sourcePress(btn, source or ("key:" .. btn)) end
    local function let(btn, source) Input:sourceRelease(btn, source or ("key:" .. btn)) end
    local function tap(game, btn) hold(btn); tick(game); let(btn); tick(game) end
    local function crowdPresses()
      local out = {}
      for _, e in ipairs(modLog) do if e.who == "crowd" then out[#out + 1] = e end end
      return out
    end
    local function finishHolds(game)
      local cur = current
      current = nil
      for _ = 1, 20 do
        if not (I.state.held or I.state.playerHeld) then break end
        tick(game)
      end
      current = cur
    end
    setOpt("events", "off")   -- events are tested on their own, below

    -- ---- the settings behind the speeds
    local B, H = I.SPEEDS.brdjesus, I.SPEEDS.helix
    eq(B.gap .. "/" .. H.gap .. "/" .. I.PLAYER_EVERY, "30/11/36",
      tag .. "steps: 0.5 s (BRDJESUS) / set 11 for HELIX (lands ~0.22 s), your HELIX input every 0.6 s")
    eq(B.wander .. "/" .. H.wander, "0.5/0.6", tag .. "the crowd's size wanders +-50% / +-60%")
    local function roles(c) return c.roles.follow .. "/" .. c.roles.noise .. "/" .. c.roles.herd .. "/" .. c.roles.troll end
    eq(roles(B), "45/35/13/7", tag .. "BRDJESUS: followers / noise / herders / trolls")
    eq(roles(H), "40/40/11/9", tag .. "HELIX: followers / noise / herders / trolls")
    eq(I.HOLD .. "/" .. I.HOLD_FACE, "12/2", tag .. "a direction is held 12 frames, A/B/START/SELECT 2")
    eq(B.event .. "@" .. B.eventEvery, "0.25@900", tag .. "BRDJESUS: a 1 in 4 event chance every 15 s")
    check(math.abs(H.event - 1 / 3) < 1e-9 and H.eventEvery == 600, tag .. "HELIX: a 1 in 3 event chance every 10 s")
    check(not B.queue and H.queue, tag .. "only HELIX queues your own input")

    -- who presses: the shares, drawn
    for name, c in pairs({ brdjesus = B, helix = H }) do
      local n, got = 100000, { follow = 0, noise = 0, herd = 0, troll = 0 }
      for _ = 1, n do local k = I.pickRole(c); got[k] = got[k] + 1 end
      local ok = true
      for k, w in pairs(c.roles) do if math.abs(got[k] / n - w / 100) > 0.008 then ok = false end end
      check(ok, tag .. name .. (": roles come up in their shares (%.3f/%.3f/%.3f/%.3f)"):format(
        got.follow / n, got.noise / n, got.herd / n, got.troll / n))
      local rest = c.roles.noise + c.roles.herd + c.roles.troll
      got = { follow = 0, noise = 0, herd = 0, troll = 0 }
      for _ = 1, n do local k = I.pickRole(c, true); got[k] = got[k] + 1 end
      check(got.follow == 0 and math.abs(got.noise / n - c.roles.noise / rest) < 0.008,
        tag .. name .. ": with nothing of yours to copy, the rest of the crowd fills in, by share")
    end
    -- the crowd's size: busier, normal or quieter
    for name, c in pairs({ brdjesus = B, helix = H }) do
      local seen = {}
      for _ = 1, 300 do seen[I.newCrowd(c)] = true end
      check(seen[1 - c.wander] and seen[1] and seen[1 + c.wander], tag .. name .. ": the crowd's size swings both ways")
      local count = 0
      for _ in pairs(seen) do count = count + 1 end
      eq(count, 3, tag .. name .. ": and only to those three sizes")
    end

    -- ---- how often: the gaps average out to the speed
    for _, sp in ipairs({ { "brdjesus", B.gap }, { "helix", H.gap } }) do
      local game = newGame(); current = { a = true }
      run(sp[1], 600 * 180, game)
      local cp = crowdPresses()
      local avg = (cp[#cp].t - cp[1].t) / math.max(1, #cp - 1)
      check(avg > sp[2] * 0.88 and avg < sp[2] * 1.12,
        tag .. sp[1] .. (": a crowd press about every %d steps (averaged %.1f over 30 minutes)"):format(sp[2], avg))
      local onlyA = true
      for _, b in ipairs(edgesSeen) do if b ~= "a" then onlyA = false end end
      check(onlyA, tag .. sp[1] .. ": only buttons the screen allows are pressed")
      -- with every button allowed too: a direction's 12-frame hold sets a
      -- floor under the gap after it, and the time lost to it is won back
      -- within each 10 s.  On HELIX the busiest stretches are faster than
      -- that floor allows; its gap is set so it still lands at 0.22 s.
      game = newGame()
      current = { up = true, down = true, left = true, right = true, a = true, b = true, start = true, select = true }
      run(sp[1], 600 * 180, game)
      cp = crowdPresses()
      avg = (cp[#cp].t - cp[1].t) / math.max(1, #cp - 1)
      local want = sp[1] == "helix" and 13.2 or sp[2]
      check(avg > want * 0.92 and avg < want * 1.08,
        tag .. sp[1] .. (": with every button allowed, about every %.1f steps (averaged %.1f)"):format(want, avg))
    end
    do
      local game = newGame()
      eq(#run("helix", 600, game), 0, tag .. "a screen it stays out of gets no crowd press")
      game = newGame(); current = { up = true }
      eq(#run("digrat", 600, game), 0, tag .. "an old DIGRAT setting reads as OFF")
      check(not I.viewInstalled(), tag .. "(and nothing is put in place)")
    end
    -- never two of its own presses at once, never closer than the last
    -- press's hold, in either speed
    for _, sp in ipairs({ "brdjesus", "helix" }) do
      local game = newGame()
      current = { up = true, down = true, left = true, right = true, a = true, b = true, start = true, select = true }
      setOpt("events", "on")
      run(sp, 600 * 30, game)
      local overlapOk, gapOk = true, true
      for i = 2, #modLog do
        local prev, e = modLog[i - 1], modLog[i]
        if e.t - prev.t < I.holdFor(prev.btn) + 1 then gapOk = false end
      end
      check(gapOk and #modLog > 100, tag .. sp .. ": each press starts only after the last one finished")
      setOpt("events", "off")
    end
    do
      local game = newGame(); current = { up = true, a = true, b = true, start = true, select = true }
      setOpt("speed", "helix")
      local overlap = false
      for i = 1, 18 * 200 do
        if i % 25 == 0 then tap(game, ({ "up", "a", "left", "b" })[(i / 25) % 4 + 1]) end
        tick(game)
        if I.state.held and I.state.playerHeld then overlap = true end
      end
      check(not overlap, tag .. "the crowd and your queued HELIX command never overlap")
    end

    -- ---- holds: 12 frames for a direction, 2 for the rest
    do
      local game = newGame(); current = { up = true }
      run("helix", 600, game)
      finishHolds(game)
      local held = 0
      for _, b in ipairs(edgesSeen) do if b == "up" then held = held + 1 end end
      local frames = 0
      game = newGame(); current = { up = true }
      setOpt("speed", "helix")
      edgesSeen, modLog = {}, {}
      for _ = 1, 600 do tick(game); if Input:isDown("up") then frames = frames + 1 end end
      current = nil
      for _ = 1, 20 do if not I.state.held then break end tick(game); if Input:isDown("up") then frames = frames + 1 end end
      eq(frames / math.max(1, #crowdPresses()), 12, tag .. "a direction is held 12 frames")
    end
    for _, btn in ipairs({ "a", "b", "start", "select" }) do
      local game = newGame(); current = { [btn] = true }
      setOpt("speed", "brdjesus")
      edgesSeen, modLog = {}, {}
      local frames = 0
      for _ = 1, 3000 do tick(game); if Input:isDown(btn) then frames = frames + 1 end end
      current = nil
      for _ = 1, 5 do if not I.state.held then break end tick(game); if Input:isDown(btn) then frames = frames + 1 end end
      eq(frames / math.max(1, #crowdPresses()), 2, tag .. btn .. " is held for 2 frames")
    end

    -- ---- it starts only once you are back in the overworld
    do
      local game = newGame(); current = { up = true }
      ow = false
      eq(#run("brdjesus", 600, game), 0, tag .. "turned on in a menu: nothing until the overworld")
      ow = true
      for _ = 1, 600 do tick(game) end
      check(#edgesSeen > 5, tag .. "back in the overworld: it starts")
      ow, lockv, topv = false, true, { "options" }
      local before = #edgesSeen
      for _ = 1, 600 do tick(game) end
      eq(#edgesSeen, before, tag .. "a settings screen pauses it")
      lockv, topv = false, { "the PC" }
      for _ = 1, 600 do tick(game) end
      eq(#edgesSeen, before, tag .. "and it stays paused on the way back")
      ow, topv = true, false
      for _ = 1, 600 do tick(game) end
      check(#edgesSeen > before + 5, tag .. "until the overworld")
      ow = false
      setOpt("speed", "helix")
      before = #edgesSeen
      for _ = 1, 300 do tick(game) end
      eq(#edgesSeen, before, tag .. "changing the speed waits for the overworld too")
      -- a held direction is let go the moment its screen stops allowing it
      game = newGame(); current = { up = true }
      setOpt("speed", "brdjesus")
      for _ = 1, 200 do tick(game); if I.state.held then break end end
      local holding = Input:isDown("up")
      current, topv = nil, { "new screen" }
      tick(game)
      check(holding and not Input:isDown("up"), tag .. "a held press is let go at once when the screen changes")
    end

    -- ---- the mix the noise draws from: 8:2, 7:3 and 6:4, swinging every 10 s
    do
      local counts, N = { [0.8] = 0, [0.7] = 0, [0.6] = 0 }, 60000
      for _ = 1, N do local m = I.newMix(); counts[m] = counts[m] + 1 end
      local f8, f7, f6 = counts[0.8] / N, counts[0.7] / N, counts[0.6] / N
      check(f8 > 0.25 and f8 < 0.30, tag .. ("8:2 comes up a bit less often (%.3f)"):format(f8))
      check(f7 > 0.34 and f7 < 0.39 and f6 > 0.34 and f6 < 0.39,
        tag .. ("7:3 and 6:4 about equally (%.3f / %.3f)"):format(f7, f6))
      for _, share in ipairs({ 0.8, 0.7, 0.6 }) do
        local moves, n = 0, 40000
        for _ = 1, n do
          local b = I.pick(Ctx.ALL, share)
          if b == "up" or b == "down" or b == "left" or b == "right" then moves = moves + 1 end
        end
        local got = moves / n
        check(math.abs(got - share) < 0.012, tag .. ("at %d:%d the directions are %.3f"):format(share * 10, 10 - share * 10, got))
      end
      local game = newGame()
      current = { up = true, down = true, left = true, right = true, a = true, b = true, start = true, select = true }
      setOpt("speed", "brdjesus")
      edgesSeen, modLog = {}, {}
      local mixes, crowds, offBeat, lastM, lastC = {}, {}, 0, nil, nil
      for _ = 1, 600 * 120 do
        tick(game)
        local m, c = I.state.mix, I.state.crowd
        if lastM and (m ~= lastM or c ~= lastC) and I.state.beat ~= 0 then offBeat = offBeat + 1 end
        mixes[m], crowds[c] = true, true
        lastM, lastC = m, c
      end
      check(mixes[0.8] and mixes[0.7] and mixes[0.6], tag .. "over 20 minutes all three mixes come up")
      check(crowds[0.5] and crowds[1] and crowds[1.5], tag .. "and all three crowd sizes")
      eq(offBeat, 0, tag .. "the mix and the crowd's size only change on the 10-second beat")
      local seen = {}
      for _, b in ipairs(edgesSeen) do seen[b] = true end
      eq(keys(seen), ALL, tag .. "every allowed button comes up, SELECT included")
      game = newGame(); current = { a = true, b = true }
      local onlyFace = true
      for _, b in ipairs(run("brdjesus", 1200, game)) do if b ~= "a" and b ~= "b" then onlyFace = false end end
      check(onlyFace, tag .. "with no direction allowed, only the others come up")
    end

    -- ---- what the followers remember of you
    do
      local mem = I.state.memory
      local function memStr() return table.concat(mem, ",") end
      local game = newGame()             -- current = nil: no crowd, nothing taken
      setOpt("speed", "brdjesus")
      tick(game)
      for _ = 1, 5 do tap(game, "a") end
      eq(memStr(), "a,a", tag .. "mashing A five times is remembered twice, no more")
      tap(game, "b"); tap(game, "a")
      eq(memStr(), "a,a,b,a", tag .. "a different button starts a new run")
      for _, b in ipairs({ "up", "down", "up", "down", "left", "right" }) do tap(game, b) end
      eq(#mem, I.MEMORY_SIZE, tag .. "it holds the last 8 inputs")
      eq(mem[1], "b", tag .. "(the two oldest, the mashed A's, went first)")
      topv = { "another screen" }
      tick(game)
      eq(#mem, I.MEMORY_SIZE, tag .. "it carries over when the screen changes")
      ow, lockv, topv = false, true, { "options" }
      tick(game)
      eq(#mem, 0, tag .. "it is forgotten when you open a settings screen")
      ow, lockv, topv = true, false, false
      tick(game)
      -- your off switch is never remembered
      hold("start", "key:return"); tick(game)
      hold("select", "key:rshift")
      for _ = 1, 5 do tick(game) end
      let("select", "key:rshift"); let("start", "key:return")
      tick(game)
      eq(memStr(), "", tag .. "START+SELECT (the off switch) is never remembered")
      eq(speedNow(), "brdjesus", tag .. "(let go before a quarter second: still on)")
      -- the crowd's own presses are not yours
      game = newGame(); current = { up = true }
      run("brdjesus", 1200, game)
      eq(memStr(), "", tag .. "the crowd's own presses are never remembered as yours")
      check(#crowdPresses() > 10, tag .. "(the crowd did press)")
    end
    -- followers copy you, oldest first, each input once, only where the
    -- screen allows it
    do
      local saved = B.roles
      B.roles = { follow = 100, noise = 0, herd = 0, troll = 0 }
      local game = newGame()
      current = { left = true, a = true, b = true }
      setOpt("speed", "brdjesus")
      tick(game)
      tap(game, "left"); tap(game, "a"); tap(game, "b")
      local mem = I.state.memory
      eq(table.concat(mem, ","), "left,a,b", tag .. "(you pressed LEFT, A, B)")
      modLog = {}
      for _ = 1, 600 do tick(game); if #mem == 0 then break end end
      local order = {}
      for _, e in ipairs(crowdPresses()) do order[#order + 1] = e.btn end
      eq(table.concat(order, ","), "left,a,b", tag .. "followers copy you in order, each input once")
      -- one the screen won't allow waits for one that does
      game = newGame(); current = { up = true }
      setOpt("speed", "brdjesus")
      tick(game)
      tap(game, "a")
      modLog = {}
      for _ = 1, 300 do tick(game) end
      eq(table.concat(mem, ","), "a", tag .. "an A the screen won't take stays remembered")
      local noA = true
      for _, e in ipairs(crowdPresses()) do if e.btn == "a" then noA = false end end
      check(noA and #crowdPresses() > 0, tag .. "and the crowd presses what the screen allows instead")
      current = { up = true, a = true }
      for _ = 1, 300 do tick(game); if #mem == 0 then break end end
      eq(#mem, 0, tag .. "on a screen that takes it, a follower uses it")
      B.roles = saved
      -- followers are still crowd presses: an A where A is never pressed
      -- (RELEASE, SAVE) is never copied there
      B.roles = { follow = 100, noise = 0, herd = 0, troll = 0 }
      game = newGame(); current = Ctx.NO_A_START
      setOpt("speed", "brdjesus")
      tick(game)
      tap(game, "a"); tap(game, "start")
      modLog = {}
      for _ = 1, 600 do tick(game) end
      local bad = false
      for _, e in ipairs(crowdPresses()) do if e.btn == "a" or e.btn == "start" then bad = true end end
      check(not bad, tag .. "followers never copy A or START onto a screen where those are never pressed")
      B.roles = saved
    end
    -- herders repeat the last crowd press; trolls press START or the griefer's direction
    do
      local game = newGame()
      current = { up = true, down = true, left = true, right = true, a = true, b = true, start = true, select = true }
      setOpt("speed", "brdjesus")
      tick(game)
      I.state.lastSent = "left"
      local saved = B.roles
      B.roles = { follow = 0, noise = 0, herd = 100, troll = 0 }
      local same = true
      for _ = 1, 200 do if I.crowdButton(B, current, Input) ~= "left" then same = false end end
      check(same, tag .. "herders repeat the crowd's last press")
      B.roles = { follow = 0, noise = 0, herd = 0, troll = 100 }
      I.state.griefer = "down"
      local okT, sawStart, sawDown = true, false, false
      for _ = 1, 400 do
        local b = I.crowdButton(B, current, Input)
        if b == "start" then sawStart = true elseif b == "down" then sawDown = true else okT = false end
      end
      check(okT and sawStart and sawDown, tag .. "trolls press START or the griefer's direction")
      B.roles = saved
      reset()
    end

    -- ---- events
    do
      -- how often they start, each 10 s
      setOpt("events", "on")
      for name, c in pairs({ brdjesus = B, helix = H }) do
        local n, started = 20000, 0
        for _ = 1, n do
          I.state.event, I.state.lullLeft = nil, 0
          I.onEventBeat(c)
          if I.state.event or I.state.lullLeft > 0 then started = started + 1 end
        end
        check(math.abs(started / n - c.event) < 0.012,
          tag .. name .. (": an event starts on about %d%% of its rolls (%.3f)"):format(c.event * 100 + 0.5, started / n))
      end
      setOpt("events", "off")
      local any = false
      for _ = 1, 5000 do
        I.state.event, I.state.lullLeft = nil, 0
        I.onEventBeat(H)
        if I.state.event or I.state.lullLeft > 0 then any = true end
      end
      check(not any, tag .. "EVENTS OFF: none ever start")
      local fromBeat = false
      setOpt("events", "on")
      for _ = 1, 5000 do
        I.state.event, I.state.lullLeft = nil, 0
        I.onBeat(H)
        if I.state.event or I.state.lullLeft > 0 then fromBeat = true end
      end
      check(not fromBeat, tag .. "(the 10 s crowd beat itself never starts one)")
      setOpt("events", "off")
      -- the roll comes round every 15 s on BRDJESUS, every 10 s on HELIX
      for name, c in pairs({ brdjesus = B, helix = H }) do
        local game = newGame(); current = { a = true }
        setOpt("speed", name)
        tick(game)
        local rolls, saved = {}, I.onEventBeat
        local t0 = I.state.tick
        local seenAt = {}
        for _ = 1, c.eventEvery * 4 + 1 do
          local before = I.state.eventBeat
          tick(game)
          if I.state.eventBeat == 0 and before ~= 0 then seenAt[#seenAt + 1] = I.state.tick end
        end
        local spacingOk = #seenAt >= 3
        for i = 2, #seenAt do if seenAt[i] - seenAt[i - 1] ~= c.eventEvery then spacingOk = false end end
        check(spacingOk, tag .. name .. (": the event roll comes every %d s"):format(c.eventEvery / 60))
      end
      I.state.event, I.state.lullLeft = nil, 0
      -- a riot: START, again and again, 10 steps apart
      local game = newGame()
      current = { up = true, down = true, left = true, right = true, a = true, b = true, start = true, select = true }
      setOpt("speed", "brdjesus")
      tick(game)
      I.startEvent("riot")
      local n = I.state.event.left
      check(n >= I.RIOT_PRESSES[1] and n <= I.RIOT_PRESSES[2], tag .. "a riot is 3 to 6 presses")
      I.state.timer, I.state.gap = 0, 1
      modLog = {}
      for _ = 1, 200 do tick(game) end
      local cp = crowdPresses()
      local riotOk = true
      for i = 1, n do if not cp[i] or cp[i].btn ~= "start" then riotOk = false end end
      for i = 2, n do if cp[i] and cp[i].t - cp[i - 1].t ~= I.RIOT_GAP then riotOk = false end end
      check(riotOk, tag .. ("a riot: %d STARTs in a row, %d steps apart"):format(n, I.RIOT_GAP))
      check(I.state.event == nil, tag .. "and then it ends")
      -- a riot where START is never pressed presses nothing, and still ends
      game = newGame(); current = Ctx.NO_A_START
      setOpt("speed", "brdjesus")
      tick(game)
      I.startEvent("riot")
      I.state.timer, I.state.gap = 0, 1
      modLog = {}
      for _ = 1, 100 do tick(game) end
      local riotStart = false
      for _, e in ipairs(crowdPresses()) do if e.btn == "start" then riotStart = true end end
      check(not riotStart and I.state.event == nil, tag .. "a riot on a screen where START is never pressed: no START, and it ends")
      -- a streak: one direction, again and again
      game = newGame()
      current = { up = true, down = true, left = true, right = true, a = true, b = true }
      setOpt("speed", "brdjesus")
      tick(game)
      I.startEvent("streak")
      n = I.state.event.left
      check(n >= I.STREAK_PRESSES[1] and n <= I.STREAK_PRESSES[2], tag .. "a streak is 3 to 5 presses")
      I.state.timer, I.state.gap = 0, 1
      modLog = {}
      for _ = 1, 2000 do tick(game); if not I.state.event and #crowdPresses() >= n then break end end
      cp = crowdPresses()
      local dir = cp[1] and cp[1].btn
      local streakOk = dir == "up" or dir == "down" or dir == "left" or dir == "right"
      for i = 2, n do if not cp[i] or cp[i].btn ~= dir then streakOk = false end end
      check(streakOk, tag .. ("a streak: %d of the same direction"):format(n))
      -- a lull: a third of the rate, for 4 s
      local function pressesIn(steps, lull)
        local game2 = newGame(); current = { a = true }
        setOpt("speed", "brdjesus")
        tick(game2)
        local total = 0
        for _ = 1, 40 do
          if lull then I.startEvent("lull") end
          modLog = {}
          for _ = 1, steps do tick(game2) end
          total = total + #crowdPresses()
        end
        return total
      end
      local normal, quiet = pressesIn(I.LULL_STEPS, false), pressesIn(I.LULL_STEPS, true)
      check(quiet < normal * 0.5 and quiet > 0,
        tag .. ("a lull slows the crowd right down (%d presses against %d)"):format(quiet, normal))
    end

    -- ---- START+SELECT to stop
    for _, speed in ipairs({ "brdjesus", "helix" }) do
      local game = newGame(); current = { up = true }
      run(speed, 20, game)
      hold("start", "key:return"); hold("select", "key:rshift")
      for _ = 1, I.STOP_HOLD - 1 do tick(game) end
      eq(speedNow(), speed, tag .. speed .. ": START+SELECT for less than a quarter second does not stop it")
      tick(game)
      let("start", "key:return"); let("select", "key:rshift")
      eq(speedNow(), "off", tag .. speed .. ": START+SELECT held a quarter second turns PRAISE HELIX OFF")
      local after = #edgesSeen
      for _ = 1, 600 do tick(game) end
      eq(#edgesSeen, after, tag .. speed .. ": and nothing more is pressed")
      eq(#I.state.memory, 0, tag .. speed .. ": and the followers forget you")
      eq(game.save.options.modOptions.praise_helix.speed, "off", tag .. speed .. ": the OFF is saved in the save's options")
    end
    do
      local game = newGame(); current = { up = true }
      run("brdjesus", 10, game)
      Input:overlayPressed("start"); Input:overlayPressed("select")
      for _ = 1, I.STOP_HOLD do tick(game) end
      Input:overlayReleased("start"); Input:overlayReleased("select")
      eq(speedNow(), "off", tag .. "two fingers on the touch screen's START and SELECT stop it too")
      game = newGame(); current = { up = true }
      run("brdjesus", 10, game)
      hold("start", "pad:1:start"); hold("select", "pad:1:back")
      for _ = 1, I.STOP_HOLD do tick(game) end
      let("start", "pad:1:start"); let("select", "pad:1:back")
      eq(speedNow(), "off", tag .. "and on a gamepad")
      game = newGame(); current = { up = true }
      run("brdjesus", 10, game)
      hold("start", "key:return")
      for _ = 1, 120 do tick(game) end
      hold("select", "key:rshift"); tick(game); let("select", "key:rshift")
      for _ = 1, 120 do tick(game) end
      let("start", "key:return")
      eq(speedNow(), "brdjesus", tag .. "a brush of SELECT while holding START does not stop it")
      hold("select", "key:rshift")
      hold("start", "mod:praise_helix:999")
      for _ = 1, 120 do tick(game) end
      let("start", "mod:praise_helix:999"); let("select", "key:rshift")
      eq(speedNow(), "brdjesus", tag .. "the mod's own START with your SELECT does not stop it")
      hold("a", "key:z"); hold("b", "key:x")
      for _ = 1, 60 do tick(game) end
      let("a", "key:z"); let("b", "key:x")
      eq(speedNow(), "brdjesus", tag .. "A+B does nothing now")
      hold("select", "key:rshift"); tick(game); let("select", "key:rshift"); tick(game)
      eq(speedNow(), "brdjesus", tag .. "SELECT alone is just a button")
      -- while you hold the off switch, the crowd starts nothing new
      game = newGame(); current = { a = true, b = true }
      setOpt("speed", "helix")
      for _ = 1, 3 do tick(game) end
      modLog = {}
      hold("start", "key:return"); hold("select", "key:rshift")
      for _ = 1, I.STOP_HOLD - 1 do tick(game) end
      eq(#modLog, 0, tag .. "while START+SELECT are held, nothing new goes in")
      let("start", "key:return"); let("select", "key:rshift")
      tick(game)
      game = newGame(); current = { select = true }
      run("brdjesus", 1200, game)
      check(#crowdPresses() > 10, tag .. "the crowd presses SELECT itself")
      eq(speedNow(), "brdjesus", tag .. "and that does not stop it")
      game = newGame(); current = { start = true, select = true }
      setOpt("events", "on")
      run("helix", 3000, game)
      check(#crowdPresses() > 50, tag .. "the crowd pressing START and SELECT (riots too)...")
      eq(speedNow(), "helix", tag .. "...never stops it")
      setOpt("events", "off")
    end

    -- the soft-reset chord: a crowd press never completes A+B+START+SELECT
    do
      local game = newGame()
      current = { a = true, b = true, start = true, select = true }
      hold("a", "key:z"); hold("b", "key:x"); hold("start", "key:return")
      local chord = false
      setOpt("speed", "brdjesus")
      setOpt("events", "on")
      for _ = 1, 30 * 400 do
        I.step(game); Input:step()
        if Input.state.select and Input.state.a and Input.state.b and Input.state.start then chord = true end
        I.state.stopFor = 0          -- (A+B are held on purpose here)
      end
      check(not chord, tag .. "a crowd SELECT never completes the soft-reset chord you're holding")
      let("a", "key:z"); let("b", "key:x"); let("start", "key:return")
      setOpt("events", "off")
      setOpt("speed", "off"); tick(game)
    end

    -- ---- the SELECT+A/B display-chord guard (COLORS / TILT)
    --
    -- src/core/Game.lua's padPressedBody reads Input:isDown("select") the
    -- instant a REAL gamepad A/B/X/Y/leftshoulder press arrives, to decide
    -- whether it's half of the recomp's own SELECT+face shortcut (COLORS,
    -- TILT, ...).  SELECT is genuinely held for HOLD_FACE (2) steps, so
    -- this guard is load-bearing; exercised against the crowd, forced to
    -- press SELECT every time.
    do
      local Runtime = require("src.mods.Runtime")
      local game
      local function fireGamepad(button, phase)
        local seenSelect
        local vanilla = function(g, c) seenSelect = g.input:isDown("select") end
        Runtime.hooks:call("input.gamepad", vanilla, game, { phase = phase, button = button })
        return seenSelect
      end
      local function untilSelectHeld()
        for _ = 1, 400 do
          tick(game)
          if I.state.held and I.state.held.btn == "select" then return end
        end
      end
      game = newGame(); current = { select = true }
      setOpt("speed", "brdjesus")
      untilSelectHeld()
      check(I.state.held and I.state.held.btn == "select" and Input:isDown("select"),
        tag .. "(the crowd is genuinely holding SELECT)")
      eq(fireGamepad("b", "pressed"), false, tag .. "that held SELECT steps aside for a real B press")
      check(I.state.held and I.state.held.btn == "select" and Input:isDown("select"), tag .. "and comes straight back after")
      eq(fireGamepad("a", "pressed"), false, tag .. "and for a real A press too")
      eq(fireGamepad("left", "pressed"), true, tag .. "but not for a button that can't complete the chord")
      eq(fireGamepad("b", "released"), true, tag .. "nor for a release")
      setOpt("speed", "off"); tick(game)
      game = newGame(); current = {}
      hold("select", "pad:1:back")
      eq(fireGamepad("b", "pressed"), true, tag .. "your own real SELECT still works for a real B press")
      let("select", "pad:1:back")
      game = newGame(); current = { select = true }
      setOpt("speed", "brdjesus")
      untilSelectHeld()
      hold("select", "pad:1:back")
      eq(fireGamepad("b", "pressed"), true, tag .. "holding your own SELECT too: still seen, ours or not")
      let("select", "pad:1:back")
      setOpt("speed", "off"); tick(game)
    end

    -- ---- HELIX's queue: one of your inputs reaches the game every 0.6 s
    do
      local game = newGame()             -- current = nil: no crowd, so only you
      setOpt("speed", "helix")
      edgesSeen, modLog = {}, {}
      for _ = 1, 5 do tick(game) end
      check(I.viewInstalled(), tag .. "HELIX: the input view is in place")
      hold("a", "key:z")
      tick(game)
      eq(Input:wasPressed("a"), false, tag .. "HELIX: your A is not seen by the game right away")
      eq(Input:isDown("a"), false, tag .. "nor held")
      let("a", "key:z")
      local gotA = false
      for _ = 1, I.PLAYER_EVERY + 2 do
        tick(game)
        if Input:wasPressed("a") then gotA = true end
      end
      check(gotA, tag .. "HELIX: your A is fed in when the 0.6 s queue comes round")
      game = newGame()
      setOpt("speed", "helix")
      hold("right", "key:right")
      local rights = 0
      for _ = 1, I.PLAYER_EVERY * 5 do
        tick(game)
        if Input:wasPressed("right") then rights = rights + 1 end
      end
      let("right", "key:right")
      eq(rights, 5, tag .. "HELIX: holding RIGHT gives one RIGHT every 0.6 s (5 in 3 s)")
      game = newGame()
      setOpt("speed", "helix")
      for _, b in ipairs({ "up", "left", "select" }) do tap(game, b) end
      local fed = {}
      for _ = 1, I.PLAYER_EVERY * 4 do
        tick(game)
        for _, b in ipairs({ "up", "left", "select" }) do if Input:wasPressed(b) then fed[#fed + 1] = b end end
      end
      eq(table.concat(fed, ","), "up,left,select", tag .. "HELIX: your presses are fed in one by one, in order")
      game = newGame()
      setOpt("speed", "helix")
      for _ = 1, 5 do tap(game, "a") end
      local as = 0
      for _ = 1, I.PLAYER_EVERY * 6 do tick(game); if Input:wasPressed("a") then as = as + 1 end end
      eq(as, 2, tag .. "HELIX: mashing A five times feeds in two")
      -- the followers pull from the same queue: each input still goes in once
      local saved = H.roles
      H.roles = { follow = 100, noise = 0, herd = 0, troll = 0 }
      game = newGame(); current = { up = true, left = true, b = true }
      setOpt("speed", "helix")
      tick(game)
      modLog = {}
      for _, b in ipairs({ "up", "left", "b" }) do hold(b); tick(game); let(b) end
      for _ = 1, 200 do tick(game); if #modLog >= 3 then break end end
      local order = {}
      for i = 1, 3 do order[i] = modLog[i] and modLog[i].btn end
      eq(table.concat(order, ","), "up,left,b", tag .. "HELIX: you and the followers share one queue, each input once, in order")
      local whoCrowd = false
      for i = 1, 3 do if modLog[i] and modLog[i].who == "crowd" then whoCrowd = true end end
      check(whoCrowd, tag .. "(followers took some of it ahead of the 0.6 s tick)")
      H.roles = saved
      -- leaving HELIX gives you your buttons back at once, and takes the view out
      setOpt("speed", "brdjesus")
      current = nil
      tick(game)
      check(not I.viewInstalled() and Input.isDown == origDown and Input.wasPressed == origPressed
        and Input.step == origStep, tag .. "out of HELIX the engine's own input functions are back")
      hold("a", "key:z")
      tick(game)
      eq(Input:wasPressed("a"), true, tag .. "out of HELIX your buttons go straight through again")
      let("a", "key:z")
      -- the failsafe: if the mod stops stepping, the view takes itself out
      setOpt("speed", "helix")
      ow = true
      for _ = 1, 3 do tick(game) end
      check(I.viewInstalled(), tag .. "HELIX again: view in place")
      Input:step(); Input:step()
      check(not I.viewInstalled() and Input.isDown == origDown, tag .. "HELIX's view takes itself out if the mod stops stepping")
      hold("b", "key:x")
      Input:step()
      eq(Input:wasPressed("b"), true, tag .. "and your buttons go straight through")
      let("b", "key:x")
      Input:step()
      -- paused HELIX (a menu it stays out of) lets your input through too
      game = newGame()
      setOpt("speed", "helix")
      for _ = 1, 3 do tick(game) end
      ow, lockv, topv = false, true, { "options" }
      tick(game)
      check(not I.viewInstalled(), tag .. "paused HELIX: the view is out, so menus get your buttons directly")
      ow, lockv, topv = true, false, false
    end

    -- ---- how little it does
    do
      local game = newGame()
      setOpt("speed", "off")
      tick(game)
      calls.allowed, calls.top = 0, 0
      for _ = 1, 600 do tick(game) end
      eq(calls.top + calls.allowed, 0, tag .. "OFF: not one screen check in 10 s")
      check(Input.isDown == origDown and Input.step == origStep, tag .. "OFF: the engine's input functions untouched")
      game = newGame(); current = { up = true }
      setOpt("speed", "brdjesus")
      tick(game)
      calls.allowed = 0
      modLog = {}
      for _ = 1, 1200 do tick(game) end
      eq(calls.allowed, #crowdPresses(), tag .. "ON: the screen is classified once per press, not per frame")
    end

    Ctx.allowed, Ctx.top, Ctx.overworld, Ctx.locks = realCtx.allowed, realCtx.top, realCtx.overworld, realCtx.locks
    setOpt("speed", "off")
    tick(game)
  end
  r.release()
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
