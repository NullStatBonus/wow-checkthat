local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)

local function bind(open, now)
    local list, t = {}, { now = now or 100 }
    ns.Facts.Bind(list, function() return t.now end, function() return open ~= false end)
    return list, t
end

test("an accepted fact is one line and returns true", function()
    local list = bind()
    T.eq(ns.Facts.Report("KeepThat", "bagFull", true), true)
    T.eq(list[1], "[KeepThat] bagFull=true")
    ns.Facts.Report("KeepThat", "count", 3); ns.Facts.Report("KeepThat", "mode", "auto")
    T.eq(list[2], "[KeepThat] count=3"); T.eq(list[3], "[KeepThat] mode=auto")
    T.eq(ns.Facts.Count(), 3); T.eq(ns.Facts.Last(), "[KeepThat] mode=auto")
end)

test("nothing is recorded when no run is open", function()
    local list = bind(false)
    local ok, why = ns.Facts.Report("KeepThat", "bagFull", true)
    T.eq(ok, false); T.eq(why, "no run is open"); T.eq(#list, 0)
end)

test("bad names, keys and values are refused", function()
    local list = bind()
    local bad = {
        { {}, "k", 1 }, { "", "k", 1 }, { ("a"):rep(33), "k", 1 }, { "A B", "k", 1 },
        { "A", {}, 1 }, { "A", "", 1 }, { "A", "k k", 1 }, { "A", ("k"):rep(49), 1 },
        { "A", "k", {} }, { "A", "k", print }, { "A", "k", nil }, { "A", "k", "x\ny" },
        { "A", "k", ("v"):rep(121) }, { "A", "k", 0 / 0 }, { "A", "k", math.huge },
    }
    for i, c in ipairs(bad) do
        local ok = ns.Facts.Report(c[1], c[2], c[3])
        T.eq(ok, false, "case " .. i)
    end
    T.eq(#list, 0)
    T.eq(ns.Facts.Report("A", "k", ("v"):rep(120)), true) -- the limit itself is allowed
end)

test("one addon is limited each second and others are not", function()
    local list, t = bind()
    for i = 1, 40 do ns.Facts.Report("Flood", "k", i) end
    T.eq(#list, ns.Facts.RATE)
    T.eq(ns.Facts.Report("Other", "k", 1), true)
    t.now = t.now + 1
    T.eq(ns.Facts.Report("Flood", "k", 99), true)
end)

test("the list keeps the newest lines", function()
    local list, t = bind()
    for i = 1, 350 do
        if i % 20 == 0 then t.now = t.now + 1 end
        ns.Facts.Report("A", "k", i)
    end
    T.eq(#list, ns.Facts.MAX); T.eq(list[#list], "[A] k=350")
end)

test("report never raises for odd arguments", function()
    bind()
    T.ok(pcall(ns.Facts.Report), "no arguments")
    T.ok(pcall(ns.Facts.Report, setmetatable({}, { __index = function() error("x") end }), 1, 2))
end)

test("numbers print without noise", function()
    local list = bind()
    ns.Facts.Report("A", "n", 0.5); ns.Facts.Report("A", "m", 12)
    T.eq(list[1], "[A] n=0.5"); T.eq(list[2], "[A] m=12")
end)

test("drops are logged and accepted facts are logged", function()
    local list = bind()
    local store = { entries = {} }
    ns.Log.Bind(store, function() return true end)
    ns.Facts.Report("A", "k", 1); ns.Facts.Report("A", "k k", 1)
    local seen = {}
    for _, e in ipairs(store.entries) do seen[#seen + 1] = e.msg end
    T.eq(seen[1], "[facts] recorded A k")
    T.ok(seen[2]:find("[facts] dropped a fact from A", 1, true), seen[2])
end)

-- Plans read facts as an ordinary log: an auto step passes from a reported fact, and an older fact does not count.
local function autoRun(list)
    local plan = { kind = "plan", ct = 1, addon = "KeepThat", title = "t",
        logs = { facts = { global = "CheckThatDB", path = "global.facts", format = "strings" } },
        sections = { { id = "s", title = "S", steps = {
            { id = "a", title = "A", action = { kind = "manual", text = "t" }, expect = "e", auto = true,
              verify = { "assertions" }, assertions = { { kind = "log", source = "facts", equals = "[KeepThat] bagFull=true" } } },
            { id = "b", title = "B", action = { kind = "manual", text = "t" }, expect = "e", verify = { "player" } },
        } } } }
    local env = { CheckThatDB = { global = { facts = list } } }
    local ctx = { plan = plan, client = "classic-era", build = "1.15", character = "X", now = 100, env = env, planDigest = "d" }
    return ns.Run.New(ctx), ctx
end
test("an auto step passes from a reported fact with no click", function()
    local list = bind()
    local run, ctx = autoRun(list)
    ns.Run.Begin(run, ctx, "a")
    T.eq(ns.Run.AutoSettle(run, ctx, "a"), nil)
    ns.Facts.Report("KeepThat", "bagFull", true)
    local a = ns.Run.AutoSettle(run, ctx, "a")
    T.eq(a.verdict, "pass"); T.eq(a.evidence, "matched"); T.eq(a.by, "auto")
end)
test("a fact reported before the step opened does not count", function()
    local list = bind()
    local run, ctx = autoRun(list)
    ns.Facts.Report("KeepThat", "bagFull", true)
    ns.Run.Begin(run, ctx, "a")
    T.eq(ns.Run.AutoSettle(run, ctx, "a"), nil)
    T.eq(run.steps.a.verdict, "pending")
end)

-- The public table: what a sibling addon calls.
test("the public table has a version and a Report that never raises", function()
    local list = bind()
    local api = ns.Facts.API()
    T.eq(api.API_VERSION, 3)
    T.eq(api.Report("KeepThat", "k", 1), true); T.eq(#list, 1)
    T.eq(api.Report({}, nil, print), false)
    ns.Facts.Report = function() error("boom") end
    T.eq(api.Report("KeepThat", "k", 1), false, "an error inside is not passed on")
end)
finish()
