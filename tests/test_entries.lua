-- The offline entry runner (tools/entry_runner.lua) against the fixture addon. Issue 94.
local ns, test, T, finish = dofile("tests/harness.lua")()
local Runner = dofile("tools/entry_runner.lua")

local function same(a, b) T.ok(T.deepEq(a, b), "lists differ") end
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

test("GetBuildInfo answers with the interface number from the TOC", function()
    local r = run({ toc = TOC, steps = {} }, function() end)
    T.eq(r.interface, 11509)
    local r2 = run({ toc = HIDDEN_TOC, steps = {} }, function() end)
    T.eq(r2.interface, 16001)
    T.eq(select(4, GetBuildInfo()), 16001, "the fake client keeps the last interface it was given")
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

finish()
