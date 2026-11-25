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

test("a step without a mock says so", function()
    local r = run({ toc = TOC, steps = { { call = { addon = "MockAddon", entry = "add", args = { 1, 2 } }, returns = { 3 } } } })
    T.eq(r.steps[1].mocked, false); same(r.mocks, {})
end)

finish()
