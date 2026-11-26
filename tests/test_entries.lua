-- The offline entry runner (tools/entry_runner.lua) against the fixture addon. Issue 94.
local ns, test, T, finish = dofile("tests/harness.lua")()
local Runner = dofile("tools/entry_runner.lua")

local function same(a, b) T.same(a, b, "lists") end
local TOC = "tests/fixtures/MockAddon/MockAddon_Vanilla.toc"
local function real(H, st) _G.GetItemInfo = function() return "Real Item" end end
local function run(spec, prepare) return (Runner.run(spec, { prepare = prepare or real })) end
local function names(r) local t = {}; for _, s in ipairs(r.steps) do t[#t + 1] = s.ok end; return t end

test("an entry returns the expected values, and a wrong expectation fails", function()
    local r = run({ toc = TOC, steps = {
        { call = { addon = "MockAddon", entry = "add", args = { 2, 3 } }, returns = { 5 } },
        { call = { addon = "MockAddon", entry = "add", args = { 2, 3 } }, returns = { 6 } },
    } })
    same(names(r), { true, false })
    T.ok(r.steps[2].detail:find("expected [6]", 1, true), r.steps[2].detail)
end)

test("an entry expected to throw passes on a matching error and fails on a normal return", function()
    local r = run({ toc = TOC, steps = {
        { call = { addon = "MockAddon", entry = "boom" }, throws = "bad input" },
        { call = { addon = "MockAddon", entry = "boom" }, throws = "other text" },
        { call = { addon = "MockAddon", entry = "add", args = { 1, 1 } }, throws = "anything" },
    } })
    same(names(r), { true, false, false })
end)

test("an entry that was not registered fails the step", function()
    local r = run({ toc = TOC, steps = { { call = { addon = "MockAddon", entry = "nope" } } } })
    T.eq(r.ok, false); T.ok(r.steps[1].detail:find("not registered", 1, true))
end)

test("a mock set before load reaches a file-scope capture and a call-time lookup", function()
    local r = run({ toc = TOC, mocks = { GetItemInfo = { { args = { 7 }, returns = { "Mocked Seven" } }, { returns = { "Mocked Other" } } } },
        steps = {
            { call = { addon = "MockAddon", entry = "captured_name", args = { 7 } }, returns = { "Mocked Seven" } },
            { call = { addon = "MockAddon", entry = "live_name", args = { 9 } }, returns = { "Mocked Other" } },
            { mockCalls = { api = "GetItemInfo", count = 2 } },
        } })
    same(names(r), { true, true, true }); T.eq(r.steps[1].mocked, true)
end)

test("a mock set after load misses the capture and reaches the call-time lookup", function()
    local r = run({ toc = TOC, mockAfterLoad = true, mocks = { GetItemInfo = { returns = { "Mocked" } } }, steps = {
        { call = { addon = "MockAddon", entry = "captured_name", args = { 1 } }, returns = { "Real Item" } },
        { call = { addon = "MockAddon", entry = "live_name", args = { 1 } }, returns = { "Mocked" } },
    } })
    same(names(r), { true, true })
end)

test("mocks are restored when the run ends, also for a dotted name", function()
    local real_fn
    local r = run({ toc = TOC, mocks = { GetItemInfo = { returns = { "M" } }, ["C_Item.GetItemCount"] = { returns = { 4 } } }, steps = {} },
        function() real_fn = function() return "Real Item" end; _G.GetItemInfo = real_fn; _G.C_Item = { GetItemCount = function() return 1 end } end)
    T.eq(_G.GetItemInfo, real_fn); T.eq(_G.C_Item.GetItemCount(), 1)
    same(r.mocks, { "C_Item.GetItemCount", "GetItemInfo" })
end)

test("a fake event reaches the handler and a later call sees the state", function()
    local r = run({ toc = TOC, steps = {
        { call = { addon = "MockAddon", entry = "events_seen" }, returns = { 0 } },
        { event = { name = "MERCHANT_SHOW", args = {} } },
        { call = { addon = "MockAddon", entry = "events_seen" }, returns = { 1, "MERCHANT_SHOW" } },
        { event = { name = "BAG_UPDATE" } },
    } })
    same(names(r), { false, true, true, false })
    T.ok(r.steps[1].detail:find("[0, nil]", 1, true), r.steps[1].detail)
    T.ok(r.steps[4].detail:find("no frame registered", 1, true))
end)

test("a mock for a name off the allow list stops the run before load", function()
    local replaced = false
    local r = run({ toc = TOC, mocks = { loadstring = { returns = { 1 } } }, steps = { { call = { addon = "MockAddon", entry = "add", args = { 1, 1 } }, returns = { 2 } } } },
        function() replaced = rawget(_G, "loadstring") end)
    T.eq(r.ok, false); T.eq(r.steps[1].step, 0); T.ok(r.steps[1].detail:find("loadstring is not on the allow list", 1, true), r.steps[1].detail)
    T.eq(_G.loadstring, replaced)
end)

test("a TOC line that leaves the addon folder stops the run before any file loads", function()
    local r = run({ toc = "tests/fixtures/MockAddon/Escape.toc", steps = { { call = { addon = "MockAddon", entry = "add", args = { 1, 1 } }, returns = { 2 } } } })
    T.eq(r.ok, false); T.eq(r.steps[1].step, 0)
    T.ok(r.steps[1].detail:find("leaves the addon folder", 1, true), r.steps[1].detail)
end)

test("libraries listed through embeds.xml load first, with the addon's name, and a commented-out file does not", function()
    _G.MockLibs = nil
    local r = run({ toc = TOC, steps = { { call = { addon = "MockAddon", entry = "libs" }, returns = { "MockAddon", true, false } } } })
    same(names(r), { true })
end)

test("an XML path that leaves the addon folder stops the run before any file loads", function()
    _G.MockAddonRan = nil
    local r = run({ toc = "tests/fixtures/MockAddon/EscapeXml.toc", steps = { { call = { addon = "MockAddon", entry = "add", args = { 1, 1 } }, returns = { 2 } } } })
    T.eq(r.ok, false); T.eq(r.steps[1].step, 0)
    T.ok(r.steps[1].detail:find("leaves the addon folder: ../MockAddon/Core.lua", 1, true), r.steps[1].detail)
    T.eq(rawget(_G, "MockAddonRan"), nil)
end)

test("a step without a mock says so", function()
    local r = run({ toc = TOC, steps = { { call = { addon = "MockAddon", entry = "add", args = { 1, 2 } }, returns = { 3 } } } })
    T.eq(r.steps[1].mocked, false); same(r.mocks, {})
end)

local HIDDEN_TOC = "tests/fixtures/MockAddon/Hidden.toc"

test("at level 2 GetBuildInfo answers with the interface number from the TOC", function()
    local r = run({ toc = TOC, level = 2, steps = {} }, function() end)
    T.eq(r.interface, 11509); T.eq(r.level, 2)
    local r2 = run({ toc = HIDDEN_TOC, level = 2, steps = {} }, function() end)
    T.eq(r2.interface, 16001)
    T.eq(select(4, GetBuildInfo()), 16001, "the fake client keeps the last interface it was given")
end)

test("without a level the run keeps level 1: interface 11507 and every name insecure", function()
    local r = run({ toc = TOC, steps = {} }, function() end)
    T.eq(r.level, 1); T.eq(r.interface, 11507)
    T.eq(issecurevariable("CreateFrame"), false, "level 1 issecurevariable answers false")
    run({ toc = TOC, level = 2, steps = {} }, function() end)
    T.eq(issecurevariable("CreateFrame"), true, "level 2 knows the game names")
end)

test("an unknown level fails the load step and runs no addon file", function()
    local r = run({ toc = TOC, level = 7, steps = { { call = { addon = "MockAddon", entry = "add", args = { 1, 1 } }, returns = { 2 } } } })
    T.eq(r.ok, false)
    T.ok(r.steps[1].detail:find("offline level 7 is not supported", 1, true), r.steps[1].detail)
end)

test("a file that uses goto fails the load step with file:line text", function()
    local r = run({ toc = "tests/fixtures/MockAddon/Goto.toc", steps = {} })
    T.eq(r.ok, false); T.eq(r.steps[1].kind, "load")
    T.ok(r.steps[1].detail:find("Goto.lua:3: Lua 5.1 rejects goto", 1, true), r.steps[1].detail)
end)

test("io is hidden from addon code: a guard sees nil, a call fails, and the globals come back", function()
    local realIo, realOs = io, os
    local r = run({ toc = HIDDEN_TOC, steps = {
        { call = { addon = "MockAddon", entry = "guard_io" }, returns = { true, false } },
        { call = { addon = "MockAddon", entry = "call_io" }, throws = "attempt to index global 'io'" },
    } })
    same(names(r), { true, true })
    T.ok(io == realIo and os == realOs, "io and os are back after the run")
    T.ok(type(jit) == "table" and type(require) == "function", "jit and require are back")
end)

test("the result lists globals the addon folder read as nil, and leaves Libs out", function()
    local r = run({ toc = HIDDEN_TOC, steps = {
        { call = { addon = "MockAddon", entry = "missing_api" }, returns = { false } },
    } })
    local got = {}
    for _, n in ipairs(r.nilReads) do got[n] = true end
    T.ok(got.C_NotInThisClient, "a call-time read is recorded")
    T.ok(got.io, "the guard's read of the hidden io is recorded")
    T.ok(not got.LibReadsNil, "a read inside Libs is left out")
    T.ok(not got.GetItemInfo, "the harness's own reads are not the addon's")
    T.eq(getmetatable(_G), nil, "the recorder removed its hook")
end)

test("a global the addon assigns to a hidden name does not leak to the host", function()
    T.eq(rawget(_G, "ffi"), nil)
    run({ toc = HIDDEN_TOC, steps = {} })
    T.eq(rawget(_G, "ffi"), nil, "ffi was nil before and stays nil")
end)

test("the nil recorder passes an old __index that returns nil or false", function()
    local H = select(5, dofile("tests/harness.lua")())
    local old = { __index = function(_, k) if k == "FalseKey" then return false end end }
    setmetatable(_G, old)
    local stop = H.recordNilReads({ "@x/" })
    T.eq(_G.FalseKey, false)
    T.eq(_G.NothingHere, nil)
    stop(); setmetatable(_G, nil)
    local stop2 = H.recordNilReads({ "@x/" })
    T.eq(_G.NothingElse, nil); stop2()
end)

test("the nil recorder passes an old __index table", function()
    local H = select(5, dofile("tests/harness.lua")())
    setmetatable(_G, { __index = { InTable = 5, FalseT = false } })
    local stop = H.recordNilReads({ "@x/" })
    T.eq(_G.InTable, 5); T.eq(_G.FalseT, false); T.eq(_G.Missing, nil)
    stop(); setmetatable(_G, nil)
end)

test("a throw outside the entry's pcall still restores the globals and the metatable, and fails the run", function()
    local realIo, realOs, realDofile = io, os, dofile
    local before = getmetatable(_G)
    local r = run({ toc = HIDDEN_TOC, steps = {
        { call = { addon = "MockAddon", entry = "guard_io", args = "not a list" } },
    } })
    T.eq(r.ok, false)
    T.eq(r.steps[1].kind, "error"); T.ok(r.steps[1].detail:find("the runner failed", 1, true), r.steps[1].detail)
    T.ok(io == realIo and os == realOs and dofile == realDofile, "hidden globals are back")
    T.eq(getmetatable(_G), before, "the recorder is off")
end)

test("the nil recorder keeps an existing _G metatable and puts it back exactly", function()
    local H = select(5, dofile("tests/harness.lua")())
    local seen = {}
    local old = { __newindex = function(t, k, v) seen[#seen + 1] = k; rawset(t, k, v) end, __index = function(_, k) if k == "OldProvided" then return 7 end end }
    setmetatable(_G, old)
    local stop = H.recordNilReads({ "@x/" }, { "/libs/" })
    T.eq(OldProvided, 7, "the earlier __index still answers")
    CtNewGlobal = 1
    T.eq(seen[1], "CtNewGlobal", "the earlier __newindex still runs")
    local names = stop()
    T.eq(getmetatable(_G), old, "the same metatable is back")
    rawset(_G, "CtNewGlobal", nil); setmetatable(_G, nil)
    T.eq(#names, 0)
end)

test("a Libs or Libraries folder is left out whatever its case", function()
    local H = select(5, dofile("tests/harness.lua")())
    local stop = H.recordNilReads({ "@x/" }, { "/libs/", "/libraries/" })
    for _, src in ipairs({ "@x/LIBS/a.lua", "@x/libraries/b.lua", "@x/Sub/Libraries/c.lua", "@x/Core.lua" }) do
        local fn = load("local v = Missing_" .. src:gsub("%W", "_") .. " return v", src)
        fn()
    end
    local names = stop()
    T.eq(#names, 1, table.concat(names, ","))
    T.ok(names[1]:find("Core_lua", 1, true), names[1])
end)

test("a Libs folder above the addon folder does not hide the addon's reads", function()
    local H = select(5, dofile("tests/harness.lua")())
    local stop = H.recordNilReads({ "@/home/u/libs/MyAddon/" }, { "/libs/" })
    local fn = load("local v = Missing_Above return v", "@/home/u/libs/MyAddon/Core.lua"); fn()
    local names = stop()
    T.eq(table.concat(names, ","), "Missing_Above")
end)

test("the fake client's issecurevariable: names set up before addon code are secure", function()
    local H = select(5, dofile("tests/harness.lua")())
    H.stubClient()
    T.eq(issecurevariable("CreateFrame"), true)
    _G.SomeAddonGlobal_X = 1
    T.eq(issecurevariable("SomeAddonGlobal_X"), false)
    T.eq(issecurevariable(_G, "SomeAddonGlobal_X"), false)
    T.eq(issecurevariable({}, "k"), true)
    _G.SomeAddonGlobal_X = nil
end)

local LIFE = "tests/fixtures/MockAddon/Life.toc"
local function call(entry, args, returns) return { call = { addon = "MockAddon", entry = entry, args = args }, returns = returns } end

test("level 3: a saved value replaces the value the file set", function()
    local r = run({ toc = LIFE, level = 3, savedVariables = { MockLifeDB = { from = "saved" } }, steps = { call("db", nil, { "saved" }) } })
    T.ok(r.ok, r.steps[1].detail)
end)

test("level 3: with no saved value the file's default is kept, and saved names are nil while the files run", function()
    _G.MockLifeDB = { from = "left over" }
    local r = run({ toc = LIFE, level = 3, steps = { call("db", nil, { "file" }), call("db_at_load", nil, { "nil" }) } })
    T.ok(r.ok, r.steps[1].detail .. " / " .. r.steps[2].detail)
    T.ok(r.ok, r.steps[1].detail)
end)

test("level 3: LoadSavedVariablesFirst assigns before the files, so the file's value wins", function()
    local r = run({ toc = "tests/fixtures/MockAddon/LifeFirst.toc", level = 3, savedVariables = { MockLifeDB = { from = "saved" } },
        steps = { call("db", nil, { "file" }), call("db_at_load", nil, { "saved" }) } })
    T.ok(r.ok, r.steps[1].detail .. " / " .. r.steps[2].detail)
end)

test("level 3: ADDON_LOADED with the folder name while logged out, then PLAYER_LOGIN and PLAYER_ENTERING_WORLD", function()
    local r = run({ toc = LIFE, level = 3, steps = { call("seen", nil,
        { "ADDON_LOADED MockAddon false false; PLAYER_LOGIN nil nil true; PLAYER_ENTERING_WORLD true false true" }) } })
    T.ok(r.ok, r.steps[1].detail)
end)

test("level 3: a frame that unregistered an event no longer gets it", function()
    local r = run({ toc = LIFE, level = 3, steps = { { event = { name = "ADDON_LOADED", args = { "MockAddon" } } } } })
    T.eq(r.ok, false); T.ok(r.steps[1].detail:find("no frame registered ADDON_LOADED", 1, true), r.steps[1].detail)
end)

test("level 3: ADDON_LOADED says whether the folder holds Bindings.xml, and ADDONS_UNLOADING that the client stays open", function()
    _G.MockBindUnloading = nil
    local r = run({ toc = "tests/fixtures/MockBind/MockBind.toc", level = 3, steps = {
        { call = { addon = "MockBind", entry = "loaded" }, returns = { "MockBind true", "nil" } },
        { reload = true },
        { call = { addon = "MockBind", entry = "loaded" }, returns = { "MockBind true", "false" } } } })
    for _, s in ipairs(r.steps) do T.ok(s.ok, s.step .. ": " .. tostring(s.detail)) end
end)

test("level 2 sends no login events: an ADDON_LOADED step fires once and IsLoggedIn is true", function()
    local r = run({ toc = LIFE, level = 2, steps = { { event = { name = "ADDON_LOADED", args = { "MockAddon" } } },
        call("seen", nil, { "ADDON_LOADED MockAddon nil true" }) } })
    T.ok(r.ok, r.steps[2].detail)
end)

test("reload keeps only saved variables, as the game saves them, and logs in again", function()
    _G.MockLifeLoose = nil -- left by an earlier run in this process
    local r = run({ toc = LIFE, level = 3, steps = {
        call("set", { "changed" }, { 1 }), call("shape", nil, { true }), { reload = true },
        call("db", nil, { "changed" }), call("logouts", nil, { 1 }), call("upvalue", nil, { 0 }), call("loose", nil, { 1 }), call("logins", nil, { 2 }),
        call("shape_after", nil, { true, true, true, true }),
    } })
    for _, s in ipairs(r.steps) do T.ok(s.ok, s.kind .. " " .. s.step .. ": " .. tostring(s.detail)) end
    T.eq(#r.steps, 9)
    local seen = run({ toc = LIFE, level = 3, steps = { { reload = true }, call("seen") } })
    T.ok(seen.steps[2].detail:find("PLAYER_ENTERING_WORLD false true true", 1, true), seen.steps[2].detail)
end)

test("reload, groups and savedVariables need level 3, and a saved name must be declared", function()
    for _, spec in ipairs({ { toc = LIFE, level = 2, steps = { { reload = true } } },
        { toc = LIFE, level = 2, savedVariables = { MockLifeDB = {} }, steps = {} },
        { toc = LIFE, groups = { { steps = {} } } } }) do
        _G.MockLifeLoose = nil
        local r = run(spec)
        T.eq(r.ok, false); T.eq(r.steps[1].step, 0)
        T.ok(r.steps[1].detail:find("needs offline level 3", 1, true), r.steps[1].detail)
        T.eq(rawget(_G, "MockLifeLoose"), nil, "no addon file ran")
    end
    local r = run({ toc = LIFE, level = 3, savedVariables = { OtherDB = {} }, steps = {} })
    T.ok(r.steps[1].detail:find("savedVariables names OtherDB, which the TOC does not declare", 1, true), r.steps[1].detail)
end)

test("groups: each starts from a fresh load with its own mocks", function()
    _G.MockLifeLoose, _G.MockLifeFlag = nil, nil
    local r = run({ toc = LIFE, level = 3, mocks = { GetItemInfo = { returns = { "Block" } } }, groups = {
        { label = "a", mocks = { GetItemInfo = { returns = { "A" } } }, steps = { call("item", nil, { "A" }), call("flag", { "set" }, { "set" }),
            { mockCalls = { api = "GetItemInfo", count = 1 } } } },
        { label = "b", mocks = { GetItemInfo = { returns = { "B" } } }, steps = { call("item", nil, { "B" }), call("flag", nil, { "none" }), call("loose", nil, { 1 }),
            { mockCalls = { api = "GetItemInfo", count = 1 } } } },
        { steps = { call("item", nil, { "Block" }) } },
    } })
    for _, s in ipairs(r.steps) do T.ok(s.ok, ("group %s step %d: %s"):format(tostring(s.group), s.step, tostring(s.detail))) end
    T.eq(#r.steps, 8); T.eq(r.steps[4].group, 2); T.eq(r.steps[4].step, 1)
    T.ok(r.ok)
end)

test("an event reaches a frame that a handler created while the event ran, as before", function()
    _G.MockSpawned = nil
    local r = run({ toc = "tests/fixtures/MockAddon/Spawn.toc", steps = { { event = { name = "FOO" } } } })
    T.eq(r.steps[1].detail, "fired at 2 frame(s)")
end)

test("a handler that runs too long fails its event step with a budget message; a quick one passes", function()
    local steps = { { event = { name = "BAG_UPDATE", args = { 100 } } }, { event = { name = "BAG_UPDATE", args = { 6000000 } } } }
    local r = run({ toc = "tests/fixtures/MockAddon/Slow.toc", level = 5, steps = steps })
    T.ok(r.steps[1].ok, "100 reads are fine: " .. tostring(r.steps[1].detail))
    T.ok(not r.steps[2].ok and tostring(r.steps[2].detail):find("script ran too long", 1, true), tostring(r.steps[2].detail))
    local old = run({ toc = "tests/fixtures/MockAddon/Slow.toc", level = 4, steps = steps })
    T.ok(old.steps[2].ok, "below level 5 the same plan keeps its old result")
    T.ok(run({ toc = "tests/fixtures/MockAddon/Slow.toc", steps = steps }).steps[2].ok, "and so does a plan with no level")
end)

test("a tooltip step reads the lines the addon put on GameTooltip", function()
    local fill = { event = { name = "BAG_UPDATE", args = { 0 } } }
    local function tip(t) return { tooltip = t } end
    local steps = { fill, tip({ lines = 3 }), tip({ contains = "Sell price" }), tip({ line = 1, equals = "Title" }), tip({ line = 3, contains = "Right" }), tip({ equals = "Left" }),
        tip({ lines = 2 }), tip({ line = 2, equals = "Title" }), tip({ contains = "Nowhere" }), tip({ line = 9, contains = "x" }) }
    local r = run({ toc = "tests/fixtures/MockAddon/Tip.toc", level = 5, steps = steps })
    local ok = {}
    for i, s in ipairs(r.steps) do ok[i] = s.ok end
    T.same(ok, { true, true, true, true, true, true, false, false, false, false })
    T.ok(tostring(r.steps[7].detail):find("has 3 line(s), expected 2", 1, true), tostring(r.steps[7].detail))
    T.ok(tostring(r.steps[9].detail):find("Sell price: 5", 1, true), "a miss lists the lines: " .. tostring(r.steps[9].detail))
    T.ok(tostring(r.steps[10].detail):find("no line 9", 1, true), tostring(r.steps[10].detail))
    local empty = run({ toc = "tests/fixtures/MockAddon/Tip.toc", level = 5, steps = { tip({ lines = 0 }) } })
    T.ok(empty.steps[1].ok, "before the handler ran there are no lines")
    local grouped = run({ toc = "tests/fixtures/MockAddon/Tip.toc", level = 4, groups = { { steps = { tip({ lines = 0 }) } } } })
    T.ok(not grouped.ok and tostring(grouped.steps[1].detail):find("needs offline level 5", 1, true), "a tooltip step in a group below level 5: " .. tostring(grouped.steps[1].detail))
    local replaced = run({ toc = "tests/fixtures/MockAddon/Tip.toc", level = 5, steps = { tip({ lines = 0 }) } }, function() _G.GameTooltip = { SetOwner = function() end } end)
    T.ok(not replaced.steps[1].ok and tostring(replaced.steps[1].detail):find("replaced it", 1, true), tostring(replaced.steps[1].detail))
    local low = run({ toc = "tests/fixtures/MockAddon/Tip.toc", level = 4, steps = { tip({ lines = 0 }) } })
    T.ok(not low.ok and tostring(low.steps[1].detail):find("needs offline level 5", 1, true), tostring(low.steps[1].detail))
end)

local function secure(name, want) return { call = { addon = "MockAddon", entry = "secure", args = { name } }, returns = { want } } end
local function entry(name) return { call = { addon = "MockAddon", entry = name } } end

test("level 6: replacing a game global taints it for good, and putting the original back does not clear it", function()
    local r = run({ toc = "tests/fixtures/MockAddon/Taint.toc", level = 6, steps = {
        secure("GetMoney", true), entry("replace"), secure("GetMoney", false), entry("restore"), secure("GetMoney", false),
        secure("GetTime", true), secure("MadeUpByTheAddon", false), secure("string", true), secure("os", true) } })
    local ok = {}
    for i, s in ipairs(r.steps) do ok[i] = s.ok end
    T.same(ok, { true, true, true, true, true, true, true, true, true }, "the runner's own hiding of io and os is not taint: " .. tostring(r.steps[8].detail))
end)

test("level 6: a replace in one step and a restore in the next is caught at the end of the first step", function()
    local r = run({ toc = "tests/fixtures/MockAddon/Taint.toc", level = 6, steps = { entry("replace"), entry("restore"), secure("GetMoney", false) } })
    T.ok(r.steps[3].ok, tostring(r.steps[3].detail))
end)

test("level 6: hooksecurefunc leaves the name secure and the hook still runs", function()
    local r = run({ toc = "tests/fixtures/MockAddon/Taint.toc", level = 6, steps = { entry("hook"), secure("GetMoney", true) } })
    T.ok(r.steps[1].ok and r.steps[2].ok, tostring(r.steps[2].detail))
    local H = select(5, dofile("tests/harness.lua")())
    local restore = H.snapshot()
    T.finally(restore)
    local st = H.stubClient({ taint = true, client = "era" })
    local ran = {}
    local calls = 0
    rawset(_G, "GetMoney", function() calls = calls + 1; return 7 end)
    st.secureValue.GetMoney = rawget(_G, "GetMoney")
    hooksecurefunc("GetMoney", function(...) ran[#ran + 1] = select("#", ...) end)
    T.eq(GetMoney(1, 2), 7); T.eq(calls, 1); T.same(ran, { 2 }, "the hook gets the call's arguments after the original")
    T.raises(function() hooksecurefunc("NotAFunction", function() end) end, "Usage", "a name that is no function is a usage error")
    rawset(_G, "GetCoinage", function() return 3, nil, 5 end); st.secureValue.GetCoinage = rawget(_G, "GetCoinage")
    local handled = {}
    rawset(_G, "geterrorhandler", function() return function(e) handled[#handled + 1] = e end end)
    hooksecurefunc("GetCoinage", function() error("hook broke", 0) end)
    T.eq(select("#", GetCoinage()), 3, "the original's results survive, trailing nils too"); T.eq(handled[1], "hook broke", "the error goes to the error handler")
    st.checkTaint(); T.eq(st.tainted.GetMoney, nil)
end)

test("level 6: a replace and a restore inside one step is not seen, and levels 5 and below keep the old answer", function()
    local r = run({ toc = "tests/fixtures/MockAddon/Taint.toc", level = 6, steps = { entry("replace_and_restore"), secure("GetMoney", true) } })
    T.ok(r.steps[2].ok, "the limit is documented: " .. tostring(r.steps[2].detail))
    local old = run({ toc = "tests/fixtures/MockAddon/Taint.toc", level = 5, steps = { entry("replace"), secure("GetMoney", true) } })
    T.ok(old.steps[2].ok, "at level 5 a replaced game global still reads secure: " .. tostring(old.steps[2].detail))
end)

test("level 3 fires the lifecycle events in the order measured in game, at login and at a reload", function()
    local r = run({ toc = "tests/fixtures/MockAddon/Order.toc", level = 3, steps = { { call = { addon = "MockAddon", entry = "order" } }, { reload = true }, { call = { addon = "MockAddon", entry = "order" } } } })
    local LOGIN = "ADDON_LOADED(MockAddon,false) VARIABLES_LOADED() PLAYER_LOGIN() PLAYER_ENTERING_WORLD(true,false) SPELLS_CHANGED()"
    T.ok(r.steps[1].ok and r.steps[1].detail:find(LOGIN, 1, true), r.steps[1].detail)
    local RELOAD = "PLAYER_LEAVING_WORLD() ADDONS_UNLOADING(false) PLAYER_LOGOUT() ADDON_LOADED(MockAddon,false) VARIABLES_LOADED() PLAYER_LOGIN() PLAYER_ENTERING_WORLD(false,true) SPELLS_CHANGED()"
    T.ok(r.steps[3].ok and r.steps[3].detail:find(LOGIN .. " " .. RELOAD, 1, true), r.steps[3].detail)
end)

test("a mock that names a recording fails the load step until the runner can read recordings", function()
    local steps = { { call = { addon = "MockAddon", entry = "add", args = { 1, 1 } }, returns = { 2 } } }
    local r = run({ toc = TOC, level = 5, mocks = { GetItemInfo = { recording = "GetItemInfo(6948)" } }, steps = steps })
    T.ok(not r.ok and r.steps[1].detail:find("a recording is not supported", 1, true), tostring(r.steps[1].detail))
    local arr = run({ toc = TOC, level = 5, mocks = { GetItemInfo = { { args = { 1 }, returns = { "x" } }, { recording = "GetItemInfo(6948)" } } }, steps = steps })
    T.ok(not arr.ok, "the array form too")
    local ok = run({ toc = TOC, level = 5, mocks = { GetItemInfo = { returns = { "x" } } }, steps = steps })
    T.ok(ok.ok, "a plain mock still runs")
end)

test("levels 1 and 2 leave the stub CreateFrame and the CheckThat a prepare set after the run", function()
    _G.CreateFrame = nil
    local mine = {}
    run({ toc = TOC, steps = {} }, function() _G.CheckThat = mine end)
    T.eq(type(_G.CreateFrame), "function"); T.eq(_G.CheckThat, mine)
    run({ toc = TOC, mocks = { loadstring = {} }, steps = {} }, function() _G.CheckThat = mine end)
    T.eq(type(_G.CreateFrame), "function", "also when the load is refused"); T.eq(_G.CheckThat, mine)
end)

test("level 3: steps after a reload still say they ran with mocks", function()
    local r = run({ toc = LIFE, level = 3, mocks = { GetItemInfo = { returns = { "X" } } },
        steps = { call("item", nil, { "X" }), { reload = true }, call("item", nil, { "X" }) } })
    T.ok(r.ok); for _, s in ipairs(r.steps) do T.eq(s.mocked, true, s.kind .. " " .. s.step) end
end)

test("level 3: a block with steps and groups, or empty groups, fails the load step", function()
    local r = run({ toc = LIFE, level = 3, steps = { call("db", nil, { "x" }) }, groups = { { steps = {} } } })
    T.eq(r.ok, false); T.ok(r.steps[1].detail:find("steps or groups, not both", 1, true), r.steps[1].detail)
    r = run({ toc = LIFE, level = 3, groups = {} })
    T.eq(r.ok, false); T.ok(r.steps[1].detail:find("groups is empty", 1, true), r.steps[1].detail)
end)

test("level 3 puts the global table back after the run", function()
    _G.MockLifeLoose, _G.MockLifeDB = nil, nil
    run({ toc = LIFE, level = 3, steps = { { reload = true } } })
    T.eq(rawget(_G, "MockLifeLoose"), nil); T.eq(rawget(_G, "MockLifeDB"), nil)
end)

test("snapshot restore removes added globals and library keys and puts old values back", function()
    local H = select(5, dofile("tests/harness.lua")())
    _G.SnapKeep = 1
    local restore = H.snapshot()
    _G.SnapAdded, _G.SnapKeep, string.snapAdded = true, 2, true
    restore()
    T.eq(rawget(_G, "SnapAdded"), nil); T.eq(_G.SnapKeep, 1); T.eq(string.snapAdded, nil)
    _G.SnapKeep = nil
end)

test("snapshot restore empties a LibStub that was loaded before the snapshot", function()
    local H = select(5, dofile("tests/harness.lua")())
    local had = rawget(_G, "LibStub")
    T.finally(function() _G.LibStub = had end)
    _G.LibStub = nil
    assert(loadfile("CheckThat/Libs/LibStub/LibStub.lua"))()
    local stub = _G.LibStub
    local before = stub:NewLibrary("SnapOld", 1); before.v = 1
    local restore = H.snapshot()
    stub:NewLibrary("SnapOld", 2).v = 2
    stub:NewLibrary("SnapLib", 1).x = true
    T.ok(stub:GetLibrary("SnapLib", true), "the library registered")
    restore()
    T.eq(stub:GetLibrary("SnapLib", true), nil, "the registry is back to what it was")
    T.ok(stub:NewLibrary("SnapLib", 1), "a second load can register the same name")
    T.eq(stub:GetLibrary("SnapOld", true), before, "a library from before stays registered")
    T.eq(before.v, 1, "and holds what it held; an upgrade in place is undone")
    T.eq(select(2, stub:GetLibrary("SnapOld", true)), 1, "at its old minor")
end)

local CLOCK = "tests/fixtures/MockAddon/Clock.toc"
local function c(entry, args, returns) return { call = { addon = "MockAddon", entry = entry, args = args }, returns = returns } end
local function allOk(r) for _, s in ipairs(r.steps) do T.ok(s.ok, ("%s %s %d: %s"):format(tostring(s.group), s.kind, s.step, tostring(s.detail))) end; T.ok(r.ok) end

test("the event lists name every event the runner fires, with the same number of values", function()
    local jns = {}
    assert(loadfile("CheckThat/Model/Json.lua"))("CheckThat", jns)
    local fired = { ADDON_LOADED = 2, PLAYER_LOGIN = 0, PLAYER_ENTERING_WORLD = 2, PLAYER_LEAVING_WORLD = 0, PLAYER_LOGOUT = 0, ADDONS_UNLOADING = 1 }
    for client, interface in pairs({ era = 11509, forever = 16001 }) do
        local f = assert(io.open("tools/events/" .. client .. ".json")); local m = assert(jns.Json.Decode(f:read("*a"))); f:close()
        T.eq(m.format, 1); T.eq(m.client, client); T.eq(m.interface, interface)
        for ev, n in pairs(fired) do T.eq(m.events[ev] and m.events[ev].payload, n, client .. " " .. ev) end
    end
end)

test("level 4: a 2-second timer fires after wait 2 and not before", function()
    allOk(run({ toc = CLOCK, level = 4, steps = { c("after", { 2 }, { true }), { wait = 1.5 }, c("fired", nil, { "no" }),
        { wait = 0.5 }, c("fired", nil, { 3 }) } }))
end)

test("level 4: GetTime and time() follow the clock", function()
    allOk(run({ toc = CLOCK, level = 4, steps = { c("now", nil, { 1, 1764028800 }), { wait = 10 }, c("now", nil, { 11, 1764028810 }) } }))
end)

test("level 4: a ticker runs its iterations and a cancelled timer never runs", function()
    allOk(run({ toc = CLOCK, level = 4, steps = { c("ticker", { 1, 3 }, { true }), c("cancelled_timer", { 1 }, { true }),
        { wait = 10 }, c("ticks", nil, { 3 }), c("fired", nil, { "no" }) } }))
end)

test("level 4: timers run by due time, then in the order they were made, and a timer made inside the wait runs", function()
    allOk(run({ toc = CLOCK, level = 4, steps = { c("order", nil, { true }), { wait = 2 }, c("seen", nil, { "a,a2,b,c" }) } }))
end)

test("level 4: a timer that throws fails the wait step", function()
    local r = run({ toc = CLOCK, level = 4, steps = { c("boom_later", nil, { true }), { wait = 1 } } })
    T.eq(r.steps[2].ok, false); T.ok(r.steps[2].detail:find("late boom", 1, true), r.steps[2].detail)
end)

test("level 4: the clock goes on across a reload, its timers do not, and a group starts again", function()
    allOk(run({ toc = CLOCK, level = 4, steps = { c("after", { 5 }, { true }), { wait = 2 }, { reload = true }, c("now", nil, { 3, 1764028802 }),
        { wait = 10 }, c("fired", nil, { "no" }) } }))
    allOk(run({ toc = CLOCK, level = 4, groups = { { steps = { { wait = 4 } } }, { steps = { c("now", nil, { 1, 1764028800 }) } } } }))
end)

test("level 4: RegisterEvent refuses an event the client does not have", function()
    allOk(run({ toc = CLOCK, level = 4, steps = { c("register", { "MERCHANT_SHOW" }, { true }),
        c("register", { "NOT_AN_EVENT" }, { false, 'Frame:RegisterEvent(): Attempt to register unknown event "NOT_AN_EVENT"' }) } }))
end)

test("level 4: an event step the client lacks, or with the wrong number of values, fails before load", function()
    _G.MockAddonRan = nil
    local r = run({ toc = CLOCK, level = 4, steps = { { event = { name = "NOT_AN_EVENT" } } } })
    T.eq(r.ok, false); T.eq(r.steps[1].step, 0); T.ok(r.steps[1].detail:find("the client has no event NOT_AN_EVENT", 1, true), r.steps[1].detail)
    r = run({ toc = CLOCK, level = 4, steps = { { event = { name = "BAG_UPDATE" } } } })
    T.ok(r.steps[1].detail:find("BAG_UPDATE carries 1 value(s), 1 of them always, and the step gives 0", 1, true), r.steps[1].detail)
    r = run({ toc = CLOCK, level = 4, steps = { { event = { name = "BAG_UPDATE", args = { 0 } } }, c("seen", nil, { "BAG_UPDATE 0" }) } })
    allOk(r)
end)

test("level 4: a timer that keeps making 0-second timers fails the wait instead of hanging", function()
    local r = run({ toc = CLOCK, level = 4, steps = { c("poll_forever", nil, { true }), { wait = 1 } } })
    T.eq(r.steps[2].ok, false); T.ok(r.steps[2].detail:find("keeps making 0-second timers", 1, true), r.steps[2].detail)
end)

test("level 4: a unit event reaches the frame only for the units it registered", function()
    local r = run({ toc = CLOCK, level = 4, steps = { c("unit", { "player" }, { true }),
        { event = { name = "UNIT_HEALTH", args = { "target" } } }, { event = { name = "UNIT_HEALTH", args = { "player" } } } } })
    T.ok(r.steps[2].detail:find("no frame registered UNIT_HEALTH", 1, true), r.steps[2].detail)
    T.eq(r.steps[3].detail, "fired at 1 frame(s)")
end)

test("level 4: time{...} converts a date, and NewTicker refuses iterations that are not a number", function()
    local ostime = os.time({ year = 2026, month = 1, day = 2, hour = 12 })
    allOk(run({ toc = CLOCK, level = 4, steps = { c("time_of", nil, { true }), c("bad_ticker", nil, { false, true }) } },
        function() _G.os_time_probe = ostime end))
end)

test("level 4: a run that fails before load puts the global table back", function()
    _G.time = nil
    run({ toc = CLOCK, level = 4, steps = { { event = { name = "NOPE" } } } })
    T.eq(rawget(_G, "time"), nil)
end)

test("level 5: the client's real surface, picked by the TOC's interface", function()
    allOk(run({ toc = CLOCK, level = 5, steps = { c("typo", nil, { true, "70576" }), c("has", { "GetItemInfo" }, { "function" }) } }))
    allOk(run({ toc = CLOCK, level = 4, steps = { c("typo", nil, { false, "63000" }) } }))
    local r = run({ toc = HIDDEN_TOC, level = 5, steps = {} })
    T.ok(r.ok); T.eq(r.interface, 16001)
end)

test("level 5: a mock of a function the client lacks fails the load", function()
    local r = run({ toc = HIDDEN_TOC, level = 5, mocks = { GetItemInfo = { returns = { "x" } } }, steps = {} })
    T.eq(r.ok, false); T.ok(r.steps[1].detail:find("mock GetItemInfo: the forever client has no such function", 1, true), r.steps[1].detail)
    r = run({ toc = HIDDEN_TOC, level = 5, mocks = { ["C_Item.GetItemInfo"] = { returns = { "x" } } }, steps = {} })
    T.ok(r.ok, r.steps[1] and r.steps[1].detail)
    r = run({ toc = TOC, level = 5, mocks = { GetItemInfo = { returns = { "x" } } }, steps = { { call = { addon = "MockAddon", entry = "captured_name", args = { 1 } }, returns = { "x" } } } })
    T.ok(r.ok, r.steps[1].detail)
end)

test("levels 1 to 3 keep GetTime at 1 and timers queued, check no event list, and refuse a wait step", function()
    local r = run({ toc = CLOCK, level = 3, steps = { c("after", { 0 }, { true }), c("fired", nil, { "no" }), c("register", { "NOT_AN_EVENT" }, { true }),
        { event = { name = "NOT_AN_EVENT" } } } })
    T.ok(r.steps[1].ok and r.steps[2].ok and r.steps[3].ok, r.steps[2].detail .. " / " .. r.steps[3].detail)
    T.eq(r.steps[4].detail, "fired at 1 frame(s)", "below level 4 any event name registers and fires")
    T.eq(GetTime(), 1)
    for lv = 1, 3 do
        r = run({ toc = CLOCK, level = lv, steps = { { wait = 1 } } })
        T.eq(r.ok, false); T.ok(r.steps[1].detail:find("a wait step needs offline level 4", 1, true), r.steps[1].detail)
    end
end)

finish()
