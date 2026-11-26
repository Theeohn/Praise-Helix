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
    eq(table.concat(speeds, " "), "OFF DIGRAT BRDJESUS HELIX", tag .. "speeds")

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
      s.playerTimer, s.playerHeld, s.lastSeen, s.top = 0, nil, nil, false
      for k in pairs(s.oursHeld) do s.oursHeld[k] = nil end
      current, topv, ow, lockv = nil, false, true, false
    end
    local function newGame()
      reset()
      return { input = Input, mods = r.loader, save = { options = {} }, writeOptions = function() end }
    end
    -- one logic tick, the way every Game does it: input.step, then Input:step
    local edgesSeen
    local function tick(game)
      I.step(game)
      Input:step()
      for _, b in ipairs(BUTTONS) do
        if Input:wasPressed(b) then edgesSeen[#edgesSeen + 1] = b end
      end
    end
    local function run(speed, steps, game)
      setOpt("speed", speed)
      edgesSeen = {}
      for _ = 1, steps do tick(game) end
      return edgesSeen
    end
    local function speedNow() return r.loader.modOptions.praise_helix.speed end
    local function hold(btn, source) Input:sourcePress(btn, source or ("key:" .. btn)) end
    local function let(btn, source) Input:sourceRelease(btn, source or ("key:" .. btn)) end

    eq(I.STEPS.digrat .. "/" .. I.STEPS.brdjesus .. "/" .. I.STEPS.helix .. "/" .. I.PLAYER_EVERY .. "/" .. I.HOLD,
      "54/30/18/54/12", tag .. "steps: 0.9 s / 0.5 s / 0.3 s, HELIX input 0.9 s, each press held 12 frames")
    local game = newGame()
    current = { up = true, a = true }
    eq(#run("digrat", 540, game), 10, tag .. "DIGRAT: one press every 0.9 s (10 in 9 s)")
    local onlyAllowed = true
    for _, b in ipairs(edgesSeen) do if b ~= "up" and b ~= "a" then onlyAllowed = false end end
    check(onlyAllowed, tag .. "only buttons the screen allows are pressed")
    game = newGame(); current = { up = true, a = true }
    eq(#run("brdjesus", 600, game), 20, tag .. "BRDJESUS: one press every 0.5 s (20 in 10 s)")
    game = newGame(); current = { up = true, a = true }
    eq(#run("helix", 540, game), 30, tag .. "HELIX: one press every 0.3 s (30 in 9 s)")
    game = newGame()
    eq(#run("helix", 600, game), 0, tag .. "a screen it stays out of gets no random press")

    -- each press is held exactly 12 frames
    game = newGame(); current = { up = true }
    setOpt("speed", "helix")
    local heldFrames, presses = 0, 0
    for t = 1, 18 * 10 + 11 do        -- ten presses, the last one held out in full
      tick(game)
      if Input:isDown("up") then heldFrames = heldFrames + 1 end
      if Input:wasPressed("up") then presses = presses + 1 end
    end
    eq(heldFrames / math.max(1, presses), 12, tag .. "each press is held 12 frames")
    -- A, B, START and SELECT are held too, just for 2 frames instead of 12
    -- -- long enough to register, short of the fastest interval (18 steps).
    -- Checked against the real engine Input (not HELIX's view).
    for _, btn in ipairs({ "a", "b", "start", "select" }) do
      game = newGame(); current = { [btn] = true }
      setOpt("speed", "brdjesus")
      local downFrames, presses2 = 0, 0
      for _ = 1, 30 * 10 + 2 do
        tick(game)
        if Input:wasPressed(btn) then presses2 = presses2 + 1 end
        if Input:isDown(btn) then downFrames = downFrames + 1 end
      end
      eq(downFrames / math.max(1, presses2), 2, tag .. btn .. " is held for 2 frames, not 12 like a direction")
    end
    -- never two of its own presses overlapping: in HELIX, the chaos and
    -- your own echoed command never both show as held at once
    game = newGame(); current = { up = true, a = true, b = true, start = true, select = true }
    setOpt("speed", "helix")
    hold("left", "key:left")
    local overlap, anyHeld = false, false
    for _ = 1, 18 * 200 do
      tick(game)
      if I.state.held and I.state.playerHeld then overlap = true end
      if I.state.held or I.state.playerHeld then anyHeld = true end
    end
    let("left", "key:left")
    check(not overlap, tag .. "the chaos and your echoed HELIX command never overlap")
    check(anyHeld, tag .. "(something was pressed)")
    -- it starts only once you are back in the overworld
    game = newGame(); current = { up = true }
    ow = false
    eq(#run("brdjesus", 600, game), 0, tag .. "turned on in a menu: nothing until the overworld")
    ow = true
    for _ = 1, 600 do tick(game) end
    eq(#edgesSeen, 20, tag .. "back in the overworld: it starts")
    -- a settings screen (or a mod's START row) pauses it until the overworld again
    ow, lockv, topv = false, true, { "options" }
    local before = #edgesSeen
    for _ = 1, 600 do tick(game) end
    eq(#edgesSeen, before, tag .. "a settings screen pauses it")
    lockv, topv = false, { "the PC" }
    for _ = 1, 600 do tick(game) end
    eq(#edgesSeen, before, tag .. "and it stays paused on the way back")
    ow, topv = true, false
    for _ = 1, 600 do tick(game) end
    eq(#edgesSeen, before + 20, tag .. "until the overworld")
    -- changing the speed in a menu also waits for the overworld
    ow = false
    setOpt("speed", "helix")
    before = #edgesSeen
    for _ = 1, 300 do tick(game) end
    eq(#edgesSeen, before, tag .. "changing the speed waits for the overworld too")
    -- a held press (a direction -- the only kind still held) is let go the
    -- moment its screen stops allowing it
    game = newGame(); current = { up = true }
    run("brdjesus", 30, game)
    local holding = Input:isDown("up")
    current, topv = nil, { "new screen" }
    tick(game)
    check(holding and not Input:isDown("up"), tag .. "a held press is let go at once when the screen changes")

    -- the mix: 8:2, 7:3 and 6:4, swinging every 10 s, 8:2 a bit less often
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
    game = newGame()
    current = { up = true, down = true, left = true, right = true, a = true, b = true, start = true, select = true }
    setOpt("speed", "brdjesus")
    edgesSeen = {}
    local mixes, changesOffBeat, last = {}, 0, nil
    local expected, nEdges = 0, 0
    for t = 1, 600 * 120 do
      tick(game)
      local m = I.state.mix
      if #edgesSeen > nEdges then
        expected = expected + m * (#edgesSeen - nEdges)
        nEdges = #edgesSeen
      end
      if last and m ~= last and I.state.mixTimer ~= 0 then changesOffBeat = changesOffBeat + 1 end
      if I.state.mixTimer == 0 then mixes[m] = true end
      last = m
    end
    check(mixes[0.8] and mixes[0.7] and mixes[0.6], tag .. "over 20 minutes all three mixes come up")
    eq(changesOffBeat, 0, tag .. "the mix only changes on the 10-second beat")
    local seen, moves = {}, 0
    for _, b in ipairs(edgesSeen) do
      seen[b] = true
      if b == "up" or b == "down" or b == "left" or b == "right" then moves = moves + 1 end
    end
    eq(keys(seen), ALL, tag .. "every allowed button comes up, SELECT included")
    local share = moves / math.max(1, #edgesSeen)
    local want = expected / math.max(1, #edgesSeen)
    check(math.abs(share - want) < 0.04,  -- ~4 sigma over 2400 presses
      tag .. ("over the run the directions follow the mixes in force (%.3f, expected %.3f)"):format(share, want))
    game = newGame(); current = { a = true, b = true }
    local onlyFace = true
    for _, b in ipairs(run("brdjesus", 600, game)) do if b ~= "a" and b ~= "b" then onlyFace = false end end
    check(onlyFace, tag .. "with no direction allowed, only the others come up")

    -- ---- START+SELECT to stop
    for _, speed in ipairs({ "digrat", "brdjesus", "helix" }) do
      game = newGame(); current = { up = true }
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
    end
    eq(game.save.options.modOptions.praise_helix.speed, "off", tag .. "the OFF is saved in the save's options")
    game = newGame(); current = { up = true }
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
    -- while you hold the off switch, the chaos starts nothing new
    game = newGame(); current = { a = true, b = true }
    setOpt("speed", "helix")
    for _ = 1, 3 do tick(game) end
    edgesSeen = {}
    hold("start", "key:return"); hold("select", "key:rshift")
    local pressedWhileHolding = 0
    for _ = 1, I.STOP_HOLD - 1 do
      tick(game)
      if Input:wasPressed("a") or Input:wasPressed("b") then pressedWhileHolding = pressedWhileHolding + 1 end
    end
    eq(pressedWhileHolding, 0, tag .. "while START+SELECT are held, no new A or B goes in")
    let("start", "key:return"); let("select", "key:rshift")
    tick(game)
    game = newGame(); current = { select = true }
    eq(#run("brdjesus", 600, game), 20, tag .. "the mod presses SELECT itself")
    eq(speedNow(), "brdjesus", tag .. "and that does not stop it")
    game = newGame(); current = { start = true, select = true }
    eq(#run("helix", 1080, game), 60, tag .. "the mod pressing START and SELECT never stops it")
    eq(speedNow(), "helix", tag .. "(still on)")

    -- the soft-reset chord: a random press never completes A+B+START+SELECT
    game = newGame()
    current = { a = true, b = true, start = true, select = true }
    hold("a", "key:z"); hold("b", "key:x"); hold("start", "key:return")
    local chord = false
    setOpt("speed", "brdjesus")
    for _ = 1, 30 * 200 do
      I.step(game); Input:step()
      if Input.state.select and Input.state.a and Input.state.b and Input.state.start then chord = true end
      I.state.stopFor = 0          -- (A+B are held on purpose here)
    end
    check(not chord, tag .. "a random SELECT never completes the soft-reset chord you're holding")
    let("a", "key:z"); let("b", "key:x"); let("start", "key:return")
    setOpt("speed", "off"); tick(game)

    -- ---- the SELECT+A/B display-chord guard (COLORS / TILT)
    --
    -- src/core/Game.lua's padPressedBody reads Input:isDown("select") the
    -- instant a REAL gamepad A/B/X/Y/leftshoulder press arrives, to decide
    -- whether it's half of the recomp's own SELECT+face shortcut (COLORS,
    -- TILT, ...).  SELECT is genuinely held for HOLD_FACE (2) steps, so
    -- this guard is load-bearing, not a backstop; exercised here against
    -- ordinary chaos, forced to pick SELECT every time.
    do
      local Runtime = require("src.mods.Runtime")
      local function fireGamepad(button, phase)
        local seenSelect
        local vanilla = function(g, c) seenSelect = g.input:isDown("select") end
        Runtime.hooks:call("input.gamepad", vanilla, game, { phase = phase, button = button })
        return seenSelect
      end
      game = newGame(); current = { select = true }
      setOpt("speed", "brdjesus")
      for _ = 1, 40 do
        tick(game)
        if I.state.held and I.state.held.btn == "select" then break end
      end
      check(I.state.held and I.state.held.btn == "select" and Input:isDown("select"),
        tag .. "(ordinary chaos is genuinely holding SELECT)")
      eq(fireGamepad("b", "pressed"), false, tag .. "that held SELECT steps aside for a real B press")
      check(I.state.held and I.state.held.btn == "select" and Input:isDown("select"), tag .. "and comes straight back after")
      eq(fireGamepad("a", "pressed"), false, tag .. "and for a real A press too")
      eq(fireGamepad("left", "pressed"), true, tag .. "but not for a button that can't complete the chord")
      eq(fireGamepad("b", "released"), true, tag .. "nor for a release")
      setOpt("speed", "off"); tick(game)
      -- your own SELECT, really held, still completes the shortcut for you
      game = newGame(); current = {}
      hold("select", "pad:1:back")
      eq(fireGamepad("b", "pressed"), true, tag .. "your own real SELECT still works for a real B press")
      let("select", "pad:1:back")
      -- both at once: ours steps aside, yours still shows through
      game = newGame(); current = { select = true }
      setOpt("speed", "brdjesus")
      for _ = 1, 40 do
        tick(game)
        if I.state.held and I.state.held.btn == "select" then break end
      end
      hold("select", "pad:1:back")
      eq(fireGamepad("b", "pressed"), true, tag .. "holding your own SELECT too: still seen, ours or not")
      let("select", "pad:1:back")
      setOpt("speed", "off"); tick(game)
    end

    -- ---- HELIX's queue: the game only gets one of your inputs every 0.9 s
    game = newGame()
    setOpt("speed", "helix")
    edgesSeen = {}
    for _ = 1, 5 do tick(game) end
    check(I.viewInstalled(), tag .. "HELIX: the input view is in place")
    hold("a", "key:z")
    tick(game)
    eq(Input:wasPressed("a"), false, tag .. "HELIX: your A is not seen by the game right away")
    eq(Input:isDown("a"), false, tag .. "nor held")
    let("a", "key:z")
    local gotA = false
    for _ = 1, 80 do
      tick(game)
      if Input:wasPressed("a") then gotA = true end
    end
    check(gotA, tag .. "HELIX: your A is fed in when the 0.9 s queue comes round")
    game = newGame()
    setOpt("speed", "helix")
    hold("right", "key:right")
    local rights = 0
    for _ = 1, I.PLAYER_EVERY * 5 do
      tick(game)
      if Input:wasPressed("right") then rights = rights + 1 end
    end
    let("right", "key:right")
    eq(rights, 5, tag .. "HELIX: holding RIGHT gives one RIGHT every 0.9 s (5 in 4.5 s)")
    game = newGame()
    setOpt("speed", "helix")
    for _, b in ipairs({ "up", "left", "select" }) do
      hold(b); tick(game); let(b); tick(game)
    end
    local fed = {}
    for _ = 1, I.PLAYER_EVERY do
      tick(game)
      for _, b in ipairs({ "up", "left", "select" }) do if Input:wasPressed(b) then fed[#fed + 1] = b end end
    end
    eq(table.concat(fed, ","), "select", tag .. "HELIX: of several presses in one window, the last one is fed in")
    -- leaving HELIX gives you your buttons back at once, and takes the view out
    setOpt("speed", "brdjesus")
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

    -- ---- how little it does
    game = newGame()
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
    for _ = 1, 600 do tick(game) end
    eq(calls.allowed, 20, tag .. "ON: the screen is classified once per press, not per frame")

    Ctx.allowed, Ctx.top, Ctx.overworld, Ctx.locks = realCtx.allowed, realCtx.top, realCtx.overworld, realCtx.locks
    setOpt("speed", "off")
    tick(game)
  end
  r.release()
end

print(("%d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
