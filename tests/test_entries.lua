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

local REC_ERA, REC_FOREVER = "tests/fixtures/MockAddon/Rec_Vanilla.toc", "tests/fixtures/MockAddon/Rec_Camelot.toc"
local function recCall(entry, id, returns) return { call = { addon = "MockAddon", entry = entry, args = { id } }, returns = returns } end

test("a mock can replay a call recorded in game, for the client the TOC names", function()
    local forever = run({ toc = REC_FOREVER, level = 5, mocks = { ["C_Item.GetItemInfo"] = { recording = "C_Item.GetItemInfo(6948)" } }, steps = {
        recCall("info_count", 6948, { 18 }), recCall("info_first", 6948, { "Hearthstone" }), recCall("info_count", 1, { 0 }),
        { call = { addon = "MockAddon", entry = "info_type", args = { 6948, 16 } }, returns = { "nil" } },
        { call = { addon = "MockAddon", entry = "info_type", args = { 6948, 15 } }, returns = { "number" } } } }) -- other arguments: no rule matches, the mock returns nothing
    local ok = {}
    for i, s in ipairs(forever.steps) do ok[i] = s.ok end
    T.same(ok, { true, true, true, true, true }, tostring(forever.steps[4].detail) .. " / " .. tostring(forever.steps[5].detail) .. " / " .. tostring(forever.steps[3].detail))
    local era = run({ toc = REC_ERA, level = 5, mocks = { GetItemInfo = { recording = "GetItemInfo(6948)" } }, steps = { recCall("info_old", 6948, { "Hearthstone" }) } })
    T.ok(era.steps[1].ok, "Era: " .. tostring(era.steps[1].detail))
    local arr = run({ toc = REC_FOREVER, level = 6, mocks = { ["C_Item.GetItemInfo"] = { { args = { 1 }, returns = { "x" } }, { recording = "C_Item.GetItemInfo(6948)" } } },
        steps = { recCall("info_first", 1, { "x" }), recCall("info_first", 6948, { "Hearthstone" }) } })
    T.ok(arr.steps[1].ok and arr.steps[2].ok, "the array form, mixed with a hand-written rule")
    local grouped = run({ toc = REC_FOREVER, level = 6, groups = { { label = "g", mocks = { ["C_Item.GetItemInfo"] = { recording = "C_Item.GetItemInfo(6948)" } }, steps = { recCall("info_count", 6948, { 18 }) } } } })
    T.ok(grouped.steps[1].ok, "a group's mock too")
end)

test("the committed recordings replay the vendor, trainer and auction scenes of #240", function()
    local function call(entry, i, returns) return { call = { addon = "MockAddon", entry = entry, args = { i } }, returns = returns } end
    local era = run({ toc = REC_ERA, level = 5, mocks = {
        GetTrainerServiceInfo = { { recording = "class:GetTrainerServiceInfo(2)" }, { recording = "GetTrainerServiceInfo(3)" } },
        GetTrainerServiceCost = { recording = "class:GetTrainerServiceCost(3)" },
        GetAuctionItemLink = { recording = "GetAuctionItemLink(list,1)" },
        GetMerchantItemInfo = { recording = "gear:GetMerchantItemInfo(2)" } }, steps = {
        call("trainer_row", 2, { "Mend Pet", "nil", "unavailable" }), call("trainer_row", 3, { "Journeyman Herbalist", "nil", "unavailable" }),
        call("trainer_cost", 3, { 1200 }), call("auction_link", 1, { "|cff0070dd|Hitem:13146::::::::::::::::::|h[Shell Launcher Shotgun]|h|r" }),
        call("vendor_price", 2, { 5065 }) } })
    for i, s in ipairs(era.steps) do T.ok(s.ok, "era step " .. i .. ": " .. tostring(s.detail)) end
    local forever = run({ toc = REC_FOREVER, level = 5, mocks = { GetTrainerServiceInfo = { recording = "class:GetTrainerServiceInfo(4)" } },
        steps = { call("trainer_row", 4, { "Slow Fall", "unavailable", 135992 }) } })
    T.ok(forever.ok, "forever: " .. tostring(forever.steps[1] and forever.steps[1].detail))
end)

test("a table return replays as a table, each call gets its own copy, and a table argument matches by value", function()
    local function call(entry, args, returns) return { call = { addon = "MockAddon", entry = entry, args = args }, returns = returns } end
    local key = { itemID = 2589, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
    local r = run({ toc = REC_FOREVER, level = 5, mocks = {
        ["C_MerchantFrame.GetItemInfo"] = { args = { 1 }, returns = { { name = "Coarse Thread", price = 10, stackCount = 1, isUsable = true } } },
        ["C_AuctionHouse.GetCommoditySearchResultInfo"] = { args = { 2589, 1 }, returns = { { itemID = 2589, unitPrice = 15, owners = {} } } },
        ["C_AuctionHouse.GetItemSearchResultInfo"] = { args = { key, 1 }, returns = { { itemKey = key, buyoutAmount = 300, owners = {} } } },
        ["C_AuctionHouse.GetBrowseResults"] = { returns = { { { minPrice = 1 }, { minPrice = 2 } } } } }, steps = {
        call("vendor_info", { 1 }, { "Coarse Thread", 10, 1 }), call("vendor_info", { 1 }, { "Coarse Thread", 10, 1 }),
        call("commodity_price", { 2589, 1 }, { 15, 0 }),
        call("item_result", { { itemID = 2589, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }, 1 }, { 300, 2589 }),
        call("item_result", { { itemID = 2589, itemLevel = 7, itemSuffix = 0, battlePetSpeciesID = 0 }, 1 }, {}),
        call("browse_count", {}, { 2 }) } })
    for i, s in ipairs(r.steps) do T.ok(s.ok, "step " .. i .. ": " .. tostring(s.detail)) end
end)

test("the committed Forever vendor and auction entries (measured 2026-11-27) replay as tables", function()
    local function call(entry, args, returns) return { call = { addon = "MockAddon", entry = entry, args = args }, returns = returns } end
    local r = run({ toc = REC_FOREVER, level = 5, mocks = {
        ["C_MerchantFrame.GetItemInfo"] = { recording = "C_MerchantFrame.GetItemInfo(1)" },
        ["C_AuctionHouse.GetCommoditySearchResultInfo"] = { { recording = "C_AuctionHouse.GetCommoditySearchResultInfo(2589,1)" }, { recording = "C_AuctionHouse.GetCommoditySearchResultInfo(2589,2)" } },
        ["C_AuctionHouse.GetBrowseResults"] = { recording = "C_AuctionHouse.GetBrowseResults()" } }, steps = {
        call("vendor_info", { 1 }, { "Coarse Thread", 10, 1 }), call("commodity_price", { 2589, 2 }, { 27, 0 }), call("browse_count", {}, { 20 }) } })
    for i, s in ipairs(r.steps) do T.ok(s.ok, "step " .. i .. ": " .. tostring(s.detail)) end
end)

test("a Forever gear-vendor row with a price replays from the recording (#242)", function()
    local r = run({ toc = REC_FOREVER, level = 5, mocks = { ["C_MerchantFrame.GetItemInfo"] = { recording = "gear:C_MerchantFrame.GetItemInfo(2)" } },
        steps = { { call = { addon = "MockAddon", entry = "vendor_info", args = { 2 } }, returns = { "Bastard Sword", 104, 1 } } } })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
end)

test("every read-only window call can be mocked, and no call that buys, learns or bids can", function()
    local R = dofile("tools/entry_runner.lua")
    for _, n in ipairs({ "GetMerchantNumItems", "GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantItemID", "GetNumTrainerServices", "GetTrainerServiceInfo",
        "GetTrainerServiceCost", "GetTrainerServiceSkillReq", "GetTrainerServiceLevelReq", "IsTradeskillTrainer", "GetTrainerServiceTypeFilter",
        "GetNumAuctionItems", "GetAuctionItemInfo", "GetAuctionItemLink", "C_MerchantFrame.GetItemInfo", "C_AuctionHouse.GetBrowseResults",
        "C_AuctionHouse.GetItemSearchResultInfo", "C_AuctionHouse.GetCommoditySearchResultInfo", "C_AuctionHouse.GetItemKeyInfo" }) do T.ok(R.MOCKABLE[n], n) end
    for _, n in ipairs({ "BuyMerchantItem", "BuyTrainerService", "PlaceAuctionBid", "PickupMerchantItem", "StartAuction", "C_AuctionHouse.PlaceBid",
        "C_AuctionHouse.StartCommoditiesPurchase", "C_AuctionHouse.PostItem", "C_AuctionHouse.SendBrowseQuery", "C_MerchantFrame.SellAllJunkItems" }) do T.ok(not R.MOCKABLE[n], n) end
end)

-- #214: from level 5 any function the client's surface lists can be mocked, except Lua's own and the fake client's model.
test("a surface function the closed list does not name mocks at level 5, and fails the load below it", function()
    local spec = function(level) return { toc = REC_ERA, level = level, mocks = { GetSpellInfo = { args = { 133 }, returns = { "Fireball" } }, UnitLevel = { returns = { 60 } } },
        steps = { { call = { addon = "MockAddon", entry = "spell_name", args = { 133 } }, returns = { "Fireball" } },
                  { call = { addon = "MockAddon", entry = "unit_level", args = { "target" } }, returns = { 60 } } } } end
    local r5 = run(spec(5))
    T.ok(r5.ok, tostring(r5.steps[1] and r5.steps[1].detail))
    local r4 = run(spec(4))
    T.ok(not r4.ok and tostring(r4.steps[1].detail):find("mock GetSpellInfo is not on the allow list", 1, true), tostring(r4.steps[1] and r4.steps[1].detail))
end)

test("Lua's own functions and the fake client's model cannot be mocked at level 5", function()
    for _, n in ipairs({ "loadstring", "pcall", "string.format", "strsub", "tinsert", "InCombatLockdown", "hooksecurefunc", "CreateFrame", "issecurevariable", "C_Timer.After", "RunScript" }) do
        local r = run({ toc = REC_ERA, level = 5, mocks = { [n] = { returns = { 1 } } }, steps = { recCall("spell_name", 133, { nil }) } })
        T.ok(not r.ok and tostring(r.steps[1].detail):find("mock " .. n .. " is not on the allow list", 1, true), n .. ": " .. tostring(r.steps[1] and r.steps[1].detail))
    end
    local R = dofile("tools/entry_runner.lua")
    local H = select(5, dofile("tests/harness.lua")())
    T.ok(R.mockable("date", {}, H) and R.mockable("Mixin", {}, H), "the game's Lua helpers can be mocked")
    T.ok(not R.mockable("GetSpellInfo", nil, H), "below level 5 only the closed list")
end)

test("a level 5 mock of a function the client lacks still fails as missing", function()
    local r = run({ toc = REC_FOREVER, level = 5, mocks = { GetSpellInfo = { returns = { "x" } } }, steps = { recCall("spell_name", 133, { "x" }) } })
    T.ok(not r.ok and tostring(r.steps[1].detail):find("mock GetSpellInfo: the forever client has no such function", 1, true), tostring(r.steps[1] and r.steps[1].detail))
end)

test("the addon's recordings folder adds calls and wins over the bundled file", function()
    local dir = "tests/fixtures/MockAddon/recordings"
    local r = run({ toc = REC_ERA, level = 5, recordings = dir, mocks = { GetSpellInfo = { recording = "GetSpellInfo(133)" }, GetItemInfo = { recording = "GetItemInfo(6948)" } },
        steps = { recCall("spell_name", 133, { "Fireball" }), recCall("info_old", 6948, { "Hearthstone (the addon's)" }) } })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail) .. " / " .. tostring(r.steps[2] and r.steps[2].detail))
    local function loadError(spec) local x = run(spec); return (not x.ok) and tostring(x.steps[1].detail) or "ran" end
    local missing = loadError({ toc = REC_ERA, level = 5, mocks = { GetSpellInfo = { recording = "GetSpellInfo(133)" } }, steps = { recCall("spell_name", 133, { "Fireball" }) } })
    T.ok(missing:find("no recording GetSpellInfo(133) for the era client (tools/recordings/era.json)", 1, true), missing)
    local both = loadError({ toc = REC_ERA, level = 5, recordings = dir, mocks = { GetSpellInfo = { recording = "GetSpellInfo(999)" } }, steps = { recCall("spell_name", 133, { "Fireball" }) } })
    T.ok(both:find("(tools/recordings/era.json or " .. dir .. "/era.json)", 1, true), both)
    local empty = run({ toc = REC_FOREVER, level = 5, recordings = dir, mocks = { ["C_Item.GetItemInfo"] = { recording = "C_Item.GetItemInfo(6948)" } }, steps = { recCall("info_first", 6948, { "Hearthstone" }) } })
    T.ok(empty.ok, "a folder without the client's file adds nothing: " .. tostring(empty.steps[1] and empty.steps[1].detail))
    local bad = loadError({ toc = REC_ERA, level = 5, recordings = "tests/fixtures/recordings-bad", mocks = { GetItemInfo = { recording = "GetItemInfo(6948)" } }, steps = { recCall("info_old", 6948, { "Hearthstone" }) } })
    T.ok(bad:find("tests/fixtures/recordings-bad/era.json has format 2", 1, true), bad)
    local low = loadError({ toc = REC_ERA, level = 4, recordings = dir, steps = { recCall("info_old", 6948, { "Real Item" }) } })
    T.ok(low:find("recordings needs offline level 5", 1, true), low)
end)

-- #273's first slice: offline hook steps run the developer's Lua with a small ctx API.
local HOOK_TOC, HOOKS = "tests/fixtures/MockAddon/Hook.toc", "tests/fixtures/hooks/offline_hooks.lua"
local function hk(name, extra) local s = { hook = name }; for k, v in pairs(extra or {}) do s[k] = v end; return s end
test("hook steps reach the addon's namespace, fire events and are judged like calls", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, mocks = { GetItemInfo = { returns = { "x" } } }, steps = {
        hk("count", { returns = { 0 } }),
        { event = { name = "BAG_UPDATE", args = { 0 } } },
        hk("count", { returns = { 1 } }),
        hk("fire_twice", { returns = { 2 } }),
        hk("count", { returns = { 3 } }),
        hk("info", { args = { "x" }, returns = { "era", 5, "x" } }),
        hk("mocked", { returns = { 2 } }),
        hk("boom", { throws = "bad thing" }),
        hk("same_ok"),
        hk("count", { returns = { 9 } }),
    } })
    same(names(r), { true, true, true, true, true, true, true, true, true, false })
    T.ok(r.steps[10].detail:find("returned [3], expected [9]", 1, true), r.steps[10].detail)
    T.eq(r.steps[1].kind, "hook")
end)

test("a hook that raises fails its step with the text, ctx.eq and ctx.same name the difference, and ctx.fire counts frames", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("rows"), hk("deep"), hk("boom"), hk("no_frame", { returns = { 0 } }) } })
    same(names(r), { false, false, false, true })
    T.ok(r.steps[1].detail:find("rows: expected 3, got 2", 1, true), r.steps[1].detail)
    T.ok(r.steps[2].detail:find("t.a.b: expected 2, got 1", 1, true), r.steps[2].detail)
    T.ok(r.steps[3].detail:find("threw bad thing", 1, true), r.steps[3].detail)
    T.ok(r.steps[4].detail:find("returned [0]", 1, true), "ctx.fire returns 0 when no frame registered the event")
end)

test("ctx.combat and ctx.advance drive the fake client's combat and clock", function()
    local r = run({ toc = HOOK_TOC, level = 6, hooks = HOOKS, steps = { hk("combat_timer", { returns = { true, 1 } }) } })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
end)

test("a hook sees Lua's full library while the addon's code does not", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("libs", { returns = { "table", "nil" } }) } })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
end)

test("ctx.ns follows a reload to the new load's namespace", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("mark"), hk("has_mark", { returns = { true } }), { reload = true }, hk("has_mark", { returns = { false } }) } })
    same(names(r), { true, true, true, true })
end)

test("a bad hooks file, an unknown name or a level below 5 fails the load before the addon runs", function()
    local function loadError(spec) local x = run(spec); return (not x.ok) and tostring(x.steps[1].detail) or "ran" end
    local steps = { hk("count") }
    T.ok(loadError({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("nope") } }):find("hook nope is not in " .. HOOKS, 1, true))
    T.ok(loadError({ toc = HOOK_TOC, level = 5, hooks = "tests/fixtures/hooks/missing.lua", steps = steps }):find("cannot be loaded", 1, true))
    T.ok(loadError({ toc = HOOK_TOC, level = 5, hooks = "tests/fixtures/hooks/raises.lua", steps = steps }):find("raised broken hooks file", 1, true))
    T.ok(loadError({ toc = HOOK_TOC, level = 5, hooks = "tests/fixtures/hooks/not_table.lua", steps = steps }):find("returned number, not a table", 1, true))
    T.ok(loadError({ toc = HOOK_TOC, level = 5, steps = steps }):find("a hook step needs a hooks file", 1, true))
    T.ok(loadError({ toc = HOOK_TOC, level = 4, hooks = HOOKS, steps = steps }):find("hooks needs offline level 5", 1, true))
    T.ok(loadError({ toc = HOOK_TOC, level = 4, steps = steps }):find("a hook step needs offline level 5", 1, true))
    local g = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, groups = { { steps = { hk("count", { returns = { 0 } }) } }, { steps = { hk("nope") } } } })
    T.ok(not g.ok and tostring(g.steps[1].detail):find("hook nope is not in", 1, true), "a name in a group is checked too")
end)

test("addon code a hook runs through ctx.fire and ctx.advance does not see the hidden globals", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("handler_libs", { returns = { "nil" } }), hk("timer_libs", { returns = { "nil" } }) } })
    same(names(r), { true, true })
end)

test("a hook gets every hidden global, require, dofile and loadfile included", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("all_libs", { returns = { "table", "table", "function", "function", "function", "table", "table" } }) } })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
end)

test("a hook's own nil reads are not in the addon's nil-read report", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = "tests/fixtures/MockAddon/hooks_inside.lua", steps = { hk("nil_read") } })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
    for _, n in ipairs(r.nilReads) do T.ok(n ~= "HookOnlyMissingGlobal", "a read in the hooks file is not the addon's") end
end)

test("ctx.fire checks the event against the client as an event step does", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("bad_event"), hk("short_event") } })
    same(names(r), { false, false })
    T.ok(r.steps[1].detail:find("the client has no event NOT_A_REAL_EVENT", 1, true), r.steps[1].detail)
    T.ok(r.steps[2].detail:find("ctx.fire gives 0", 1, true), r.steps[2].detail)
end)

test("a hook step keeps the addon's own value of a hidden name", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("ffi_mine", { returns = { true } }), hk("noop"), hk("ffi_mine", { returns = { true } }) } })
    same(names(r), { true, true, true })
end)

test("ctx.same compares a table that refers back to itself", function()
    local r = run({ toc = HOOK_TOC, level = 5, hooks = HOOKS, steps = { hk("cyclic") } })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
end)

test("the hooks file does not run when the load is refused for another reason", function()
    local probe = {}
    _G.HookProbe = probe
    T.finally(function() _G.HookProbe = nil end)
    local r = run({ toc = HOOK_TOC, level = 5, hooks = "tests/fixtures/hooks/marks.lua", mocks = { loadstring = { returns = { 1 } } }, steps = { hk("noop") } })
    T.ok(not r.ok and tostring(r.steps[1].detail):find("not on the allow list", 1, true), tostring(r.steps[1] and r.steps[1].detail))
    T.eq(probe.ran, nil, "the hooks file did not run")
    run({ toc = HOOK_TOC, level = 5, hooks = "tests/fixtures/hooks/marks.lua", steps = { hk("noop") } })
    T.eq(probe.ran, true, "it runs for a load that goes ahead")
end)

test("a recording that does not fit fails the load step and says why", function()
    local steps = { recCall("info_first", 6948, { "Hearthstone" }) }
    local function loadError(r) return (not r.ok) and tostring(r.steps[1].detail) or "ran" end
    T.ok(loadError(run({ toc = REC_FOREVER, level = 5, mocks = { GetItemInfo = { recording = "GetItemInfo(6948)" } }, steps = steps })):find("no recording GetItemInfo(6948) for the forever client", 1, true), "Forever has no such recording")
    T.ok(loadError(run({ toc = REC_ERA, level = 5, mocks = { ["C_Item.GetItemInfo"] = { recording = "GetItemInfo(6948)" } }, steps = steps })):find("is for another function", 1, true))
    T.ok(loadError(run({ toc = REC_ERA, level = 4, mocks = { GetItemInfo = { recording = "GetItemInfo(6948)" } }, steps = steps })):find("needs offline level 5", 1, true), "below level 5")
    T.ok(loadError(run({ toc = REC_ERA, level = 5, mocks = { GetItemInfo = { recording = "GetItemInfo(1)" } }, steps = steps })):find("no recording GetItemInfo(1) for the era client", 1, true), "an unknown label")
    T.ok(loadError(run({ toc = REC_ERA, level = 5, mocks = { GetItemInfo = { recording = "GetItemInfo(6948)", returns = { "x" } } }, steps = steps })):find("cannot be combined", 1, true), "a recording with returns")
    T.ok(run({ toc = REC_ERA, level = 5, mocks = { GetItemInfo = { returns = { "x" } } }, steps = { recCall("info_old", 1, { "x" }) } }).ok, "a plain mock still runs")
end)

test("the committed recordings name no character, realm or personal value", function()
    local jns = {}
    assert(loadfile("CheckThat/Model/Json.lua"))("CheckThat", jns)
    for _, client in ipairs({ "era", "forever" }) do
        local f = assert(io.open("tools/recordings/" .. client .. ".json")); local text = f:read("*a"); f:close()
        local rec = assert(jns.Json.Decode(text))
        T.eq(rec.format, 1); T.eq(rec.client, client); T.ok(next(rec.calls))
        T.ok(rec.rev == nil or (rec.rev >= 2 and rec.rev <= 5), "rev is absent in a file from before the window tags, or 2 to 5")
        for label, call in pairs(rec.calls) do
            T.ok(call.window == nil or call.window == "merchant" or call.window == "trainer" or call.window == "auction", label .. " has an unknown window tag")
            if call.api == "GetAuctionItemInfo" then
                for i = 12, 15 do T.ok(type(call.returns[i]) ~= "string" or call.returns[i] == "", label .. " names a bidder or a seller at return " .. i) end -- a nil is stored as false
            end
            T.ok(not label:find("player", 1, true), label .. " is a call on the player")
            for _, personal in ipairs({ "GetMoney", "GetItemCount", "UnitName", "GetRealmName", "GetTime", "GetServerTime" }) do
                T.ok(call.api ~= personal or (personal == "GetMoney" and call.window and label:find("^%l+:")), call.api .. " is personal") -- a balance is kept only beside a window scene
            end
        end
        T.ok(not text:find("|Hitem:6948::::::::10:", 1, true) and not text:find("|Hitem:%d+:[^|]*:%d+:%d+:", 1), "an item link carries no level or specialization")
    end
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

-- ct test (#273): tools/addon_test.lua hands a test function in as opts.hooks; ctx.reload, ctx.ok and ctx.raises serve tests and hooks.
local TESTED = "tests/fixtures/TestedAddon/TestedAddon_Vanilla.toc"
local function tested(fn, extra)
    local spec = { toc = TESTED, level = Runner.LEVEL, steps = { { hook = "t" } } }
    for k, v in pairs(extra or {}) do spec[k] = v end
    return (Runner.run(spec, { hooks = { t = fn }, hooksFile = "tests/fixtures/TestedAddon/tests/test_core.lua" }))
end
test("ctx.reload keeps the saved variables, gives a new load and moves ctx.ns to it", function()
    local seen = {}
    local r = tested(function(ctx)
        local old = ctx.ns
        seen.before = old.runs
        ctx.reload()
        seen.after, seen.moved = ctx.ns.runs, ctx.ns ~= old
    end, { savedVariables = { TestedAddonDB = { runs = 1 } } })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
    same(seen, { before = 2, after = 3, moved = true })
end)

test("ctx.reload raises with the handler's error when the logout fails", function()
    local r = tested(function(ctx)
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGOUT")
        f:SetScript("OnEvent", function() error("logout broke") end)
        ctx.reload()
    end)
    T.eq(r.ok, false)
    T.ok(r.steps[1].detail:find("the reload failed: PLAYER_LOGOUT handler threw", 1, true), r.steps[1].detail)
    T.ok(r.steps[1].detail:find("logout broke", 1, true), r.steps[1].detail)
end)

test("ctx.ok and ctx.raises fail with what was wrong, and ctx.raises returns the error", function()
    local function detail(fn) local r = tested(fn); return r.ok, r.steps[1].detail end
    local ok1, d1 = detail(function(ctx) ctx.ok(nil, "the flag") end)
    T.eq(ok1, false); T.ok(d1:find("the flag: expected a true value, got nil", 1, true), d1)
    local ok2, d2 = detail(function(ctx) ctx.raises(function() end, nil, "sell") end)
    T.eq(ok2, false); T.ok(d2:find("sell: expected an error, the call returned", 1, true), d2)
    local ok3, d3 = detail(function(ctx) ctx.raises(function() error("out of range") end, "in combat", "sell") end)
    T.eq(ok3, false); T.ok(d3:find('sell: expected an error containing "in combat"', 1, true), d3)
    local got
    local ok4 = detail(function(ctx) ctx.combat(true); got = ctx.raises(ctx.ns.Sell, "in combat"); ctx.ok(ctx.ns.count == 0) end)
    T.eq(ok4, true); T.ok(tostring(got):find("in combat", 1, true), tostring(got))
end)

test("a hooks table from ct test needs the named function, and a plan block still needs its hooks file", function()
    local r = Runner.run({ toc = TESTED, level = Runner.LEVEL, steps = { { hook = "nope" } } }, { hooks = { t = function() end }, hooksFile = "x/test_a.lua" })
    T.eq(r.ok, false); T.ok(r.steps[1].detail:find("hook nope is not in x/test_a.lua", 1, true), r.steps[1].detail)
    local p = run({ toc = TESTED, level = Runner.LEVEL, steps = { { hook = "t" } } })
    T.eq(p.ok, false); T.ok(p.steps[1].detail:find("a hook step needs a hooks file", 1, true), p.steps[1].detail)
end)

test("ctx.reload runs the logout as addon code and gives the test its library back", function()
    local seen = {}
    local r = tested(function(ctx)
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_LOGOUT")
        f:SetScript("OnEvent", function() seen.logoutIo = io == nil end)
        ctx.reload()
        seen.io, seen.req = io ~= nil, require ~= nil
    end)
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
    same(seen, { logoutIo = true, io = true, req = true })
end)

test("ctx.fire from a handler fires, and ctx.reload from a handler says where it runs", function()
    local seen = {}
    local r = tested(function(ctx)
        local f = CreateFrame("Frame")
        f:RegisterEvent("BAG_UPDATE")
        f:RegisterEvent("PLAYER_TARGET_CHANGED")
        f:SetScript("OnEvent", function(_, ev)
            if ev == "PLAYER_TARGET_CHANGED" then seen.nested = ctx.fire("BAG_UPDATE", 0)
            else seen.ok, seen.err = pcall(ctx.reload) end
        end)
        ctx.fire("PLAYER_TARGET_CHANGED")
    end)
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
    T.eq(seen.nested, 2, "the addon's frame and the test's frame")
    T.eq(seen.ok, false)
    T.ok(tostring(seen.err):find("ctx.reload runs from the test or hook itself", 1, true), tostring(seen.err))
end)

test("ct test's interface and addon name win over the TOC's first number and the folder", function()
    local seen = {}
    local r = Runner.run({ toc = "tests/fixtures/TestedAddon/TestedAddon.toc", level = Runner.LEVEL, steps = { { hook = "t" } } },
        { hooks = { t = function(ctx) seen.client = ctx.client; seen.build = select(4, GetBuildInfo()) end }, interface = 16001, addonName = "Named" })
    T.ok(r.ok, tostring(r.steps[1] and r.steps[1].detail))
    same(seen, { client = "forever", build = 16001 })
end)

test("an absolute path is kept on any system, and a relative one is under the root", function()
    T.eq(Runner.pathJoin("r", "/a/b.toc"), "/a/b.toc")
    T.eq(Runner.pathJoin("r", "C:\\a\\b.toc"), "C:\\a\\b.toc")
    T.eq(Runner.pathJoin("r", "C:/a/b.toc"), "C:/a/b.toc")
    T.eq(Runner.pathJoin("r", "\\\\srv\\a.toc"), "\\\\srv\\a.toc")
    T.eq(Runner.pathJoin("r", "a/b.toc"), "r/a/b.toc")
end)

finish()
