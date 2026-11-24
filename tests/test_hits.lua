local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local E, R = ns.Evidence, ns.Run
local plan = { logs = {
    s = { global = "DB", path = "log", format = "strings" },
    f = { global = "DB", path = "facts", format = "strings" } } }
local function env(lines, facts) return { DB = { log = lines, facts = facts or {} } } end
local function snapOf(a, before) return E.Snapshot(plan, env(before or {}, before or {}), { assertions = { a } }) end
local function check(a, before, after, facts)
    local snap = snapOf(a, before)
    local e = env(after, facts or after)
    return E.Check(a, snap, plan, e, true)
end

test("a check asked for no detail returns none, and Preview stays cheap", function()
    local a = { kind = "log", source = "s", contains = "x", absent = true }
    local snap = snapOf(a, { "old" })
    local r, why, d = E.Check(a, snap, plan, env({ "old", "x" }))
    T.eq(r, "fail"); T.eq(d, nil)
end)

test("a check that passes returns no detail, so it costs no second scan", function()
    local snap = snapOf({ kind = "log", source = "s", contains = "ok" }, { "old" })
    local r, _, d = E.Check({ kind = "log", source = "s", contains = "ok" }, snap, plan, env({ "old", "ok" }), true)
    T.eq(r, "pass"); T.eq(d, nil)
    local f = { kind = "fact", source = "f", addon = "KT", key = "level", op = "eq", value = 3 }
    local r2, _, d2 = check(f, {}, { "[KT] level=3" })
    T.eq(r2, "pass"); T.eq(d2, nil)
end)

test("a forbidden line fails with its position, text and a reason", function()
    local a = { kind = "log", source = "s", contains = "FAILED", absent = true, label = "no failure" }
    local r, why, d = check(a, { "old" }, { "old", "a", "[kt] FAILED: x", "b", "[kt] FAILED: y" })
    T.eq(r, "fail"); T.eq(why, "a forbidden line appeared")
    T.eq(d.kind, "log"); T.eq(d.scope, "attempt"); T.eq(d.source, "s"); T.eq(d.label, "no failure"); T.eq(d.rule, 'absent: contains "FAILED"'); T.eq(d.shape, 'absent: contains "…"', "the shape leaves the literal out")
    T.eq(d.window, 4); T.eq(d.matched, 2); T.eq(#d.hits, 2)
    T.eq(d.hits[1].n, 2, "position inside the new lines, from 1"); T.eq(d.hits[1].line, "[kt] FAILED: x"); T.eq(d.hits[2].n, 4)
end)

test("a count over its bound keeps the first line past the bound", function()
    local a = { kind = "log", source = "s", contains = "hit", count = { max = 1 } }
    local r, why, d = check(a, {}, { "hit 1", "other", "hit 2", "hit 3" })
    T.eq(r, "fail"); T.eq(d.rule, 'count at most 1: contains "hit"'); T.eq(d.matched, 3)
    T.eq(d.hits[1].n, 3, "the second match is the first one over the bound"); T.eq(d.hits[2].n, 4)
end)

test("a missing line is unverified with a count of zero and no hits; long lines are cut", function()
    local r, why, d = check({ kind = "log", source = "s", contains = "nope" }, {}, { "a", ("x"):rep(500) })
    T.eq(r, "unverified"); T.eq(d.matched, 0); T.eq(d.window, 2); T.eq(d.hits, nil)
    local _, _, d2 = check({ kind = "log", source = "s", contains = "xx", absent = true }, {}, { "a", ("x"):rep(500) })
    T.eq(#d2.hits[1].line, E.HIT_LEN)
end)

test("a lost window says what it can: the rule, and no counts", function()
    local a = { kind = "log", source = "s", contains = "x" }
    local r, why, d = E.Check(a, {}, plan, {}, true)
    T.eq(r, "unverified"); T.eq(d.rule, 'present: contains "x"'); T.eq(d.matched, nil); T.eq(d.window, nil)
end)

test("session scope counts positions in the whole log", function()
    local a = { kind = "log", source = "s", contains = "boom", absent = true, scope = "session" }
    local r, _, d = E.Check(a, nil, plan, env({ "one", "two", "boom", "three" }), true)
    T.eq(r, "fail"); T.eq(d.scope, "session"); T.eq(d.window, 4); T.eq(d.hits[1].n, 3)
end)

test("a sequence names the last item reached and the one it stopped at", function()
    local a = { kind = "log-sequence", source = "s", sequence = { { contains = "a" }, { contains = "b" }, { contains = "c" } } }
    local r, why, d = check(a, {}, { "a1", "x", "b2" })
    T.eq(r, "unverified"); T.eq(d.matched, 2); T.eq(d.stoppedAt, 3); T.eq(d.hits[1].item, 2); T.eq(d.hits[1].n, 3); T.eq(d.rule, "sequence of 3 lines")
    local r2, _, d2 = check(a, {}, { "a", "b", "c" })
    T.eq(r2, "pass"); T.eq(d2, nil, "a pass keeps no detail")
end)

test("facts cite the fact lines with their values", function()
    local f = { kind = "fact", source = "f", addon = "KT", key = "level", op = "eq", value = 3 }
    local facts = { "[KT] level=3", "noise", "[KT] level=5" }
    local r, why, d = check(f, {}, facts, facts)
    T.eq(r, "fail"); T.eq(why, "the last fact did not match"); T.eq(d.hits[1].n, 3); T.eq(d.hits[1].value, "5"); T.eq(d.hits[1].line, "[KT] level=5")
    T.eq(d.rule, "fact [KT] level eq 3")
    local r2, why2, d2 = check(f, {}, { "[KT] level=3", "[KT] level=4", "[KT] level=3", "[KT] level=9" }, nil)
    T.eq(r2, "fail"); T.eq(why2, "the last fact did not match")
    local all = { kind = "fact", source = "f", addon = "KT", key = "level", op = "eq", value = 3, which = "all" }
    local r3, why3, d3 = check(all, {}, { "[KT] level=3", "[KT] level=4", "[KT] level=3", "[KT] level=9" })
    T.eq(r3, "fail"); T.eq(why3, "a fact did not match"); T.eq(d3.hits[1].n, 2, "a violating fact, even with later ones passing"); T.eq(d3.matched, 2)
    local any = { kind = "fact", source = "f", addon = "KT", key = "level", op = "eq", value = 3, which = "any" }
    local r4, why4, d4 = check(any, {}, { "[KT] level=1", "[KT] level=2" })
    T.eq(r4, "fail"); T.eq(why4, "no fact matched"); T.eq(#d4.hits, 2); T.eq(d4.matched, 0)
    local missing = { kind = "fact", source = "f", addon = "KT", key = "level", op = "missing" }
    local r5, why5, d5 = check(missing, {}, { "[KT] level=1" })
    T.eq(r5, "fail"); T.eq(why5, "the fact arrived"); T.eq(d5.hits[1].n, 1)
end)

test("the shape of a fact or state rule leaves the value out too", function()
    local f = { kind = "fact", source = "f", addon = "KT", key = "level", op = "eq", value = "SECRET" }
    local _, _, d = check(f, {}, { "[KT] level=1" })
    T.eq(d.rule, "fact [KT] level eq SECRET"); T.eq(d.shape, "fact [KT] level eq …")
    local _, _, s = E.Check({ kind = "state", probe = "global-value", name = "G", op = "eq", value = "SECRET" }, nil, plan, { G = 2 }, true)
    T.eq(s.shape, "global-value G eq …")
end)

test("a state check keeps what it saw, as a short plain value", function()
    local a = { kind = "state", probe = "global-value", name = "G", op = "eq", value = 3 }
    local r, why, d = E.Check(a, nil, plan, { G = 2 }, true)
    T.eq(r, "fail"); T.eq(d.observed, "2"); T.eq(d.rule, "global-value G eq 3"); T.eq(d.scope, nil); T.eq(d.window, nil)
    local _, _, d2 = E.Check({ kind = "state", probe = "global-value", name = "G", op = "eq", value = 3 }, nil, plan, { G = { 1 } }, true)
    T.eq(d2.observed, "table")
end)

-- The run keeps it
local function mk(assertions)
    local p = { kind = "plan", ct = 1, addon = "KeepThat", title = "t", logs = { s = plan.logs.s },
        sections = { { id = "sec", title = "S", steps = { { id = "a", title = "A", action = { kind = "manual", text = "t" }, expect = "e",
            verify = { "player", "assertions" }, assertions = assertions } } } } }
    local e = { DB = { log = { "old" } } }
    local ctx = { plan = p, client = "classic-era", build = "1.15", character = "X", now = 100, env = e, planDigest = "d" }
    return R.New(ctx), ctx, e
end

test("a failed attempt keeps the detail of its failing checks only, and the export carries it", function()
    local run, ctx, e = mk({ { kind = "log", source = "s", contains = "boom", absent = true }, { kind = "log", source = "s", contains = "ok" } })
    R.Begin(run, ctx, "a")
    e.DB.log[#e.DB.log + 1] = "ok"; e.DB.log[#e.DB.log + 1] = "boom here"
    local at = R.Verdict(run, ctx, "a", "pass")
    T.eq(at.verdict, "fail")
    local bad, good = at.outcomes[1], at.outcomes[2]
    T.eq(bad.result, "fail"); T.eq(bad.rule, 'absent: contains "boom"'); T.eq(bad.hits[1].n, 2); T.eq(bad.hits[1].line, "boom here")
    T.eq(good.result, "pass"); T.eq(good.rule, nil); T.eq(good.hits, nil)
    T.eq(R.Export(run).steps.a.attempts[1].outcomes[1].hits[1].line, "boom here")
end)

test("a diagnostic that fails keeps its detail although the attempt passes", function()
    local run, ctx, e = mk({ { kind = "log", source = "s", contains = "ok" }, { kind = "log", source = "s", contains = "never", diagnostic = true } })
    R.Begin(run, ctx, "a"); e.DB.log[#e.DB.log + 1] = "ok"
    local at = R.Verdict(run, ctx, "a", "pass")
    T.eq(at.verdict, "pass"); T.eq(at.outcomes[2].result, "unverified"); T.eq(at.outcomes[2].rule, 'present: contains "never"'); T.eq(at.outcomes[1].rule, nil)
end)

test("under the byte budget the oldest attempts lose hit text but keep the rule and the count, and are marked", function()
    local run, ctx, e = mk({ { kind = "log", source = "s", contains = "boom", absent = true } })
    local old = R.EXCERPT_BUDGET; R.EXCERPT_BUDGET = 700
    for i = 1, 4 do
        ctx.now = 100 + i
        R.Begin(run, ctx, "a")
        e.DB.log[#e.DB.log + 1] = ("boom %d "):format(i) .. ("x"):rep(150)
        R.Verdict(run, ctx, "a", "pass")
        run.steps.a.verdict = "pending"
    end
    R.EXCERPT_BUDGET = old
    local at = run.steps.a.attempts
    local o1, o4 = at[1].outcomes[1], at[4].outcomes[1]
    T.eq(o1.hits, nil); T.eq(o1.trimmed, true); T.eq(o1.rule, 'absent: contains "boom"'); T.eq(o1.matched, 1); T.eq(at[1].excerpt, nil)
    T.ok(o4.hits and o4.hits[1].line:find("boom 4", 1, true)); T.eq(o4.trimmed, nil)
end)

-- The Python tools read what the addon wrote: this file is validated against schema/run-results.schema.json by tools/test_ct.py.
test("the run a failing step leaves is written out for the tools", function()
    local run, ctx, e = mk({ { kind = "log", source = "s", contains = "boom", absent = true }, { kind = "log-sequence", source = "s", sequence = { { contains = "a" }, { contains = "zz" } } },
        { kind = "state", probe = "global-value", name = "G", op = "eq", value = 3, diagnostic = true } })
    e.G = 2; ctx.env = e
    R.Begin(run, ctx, "a")
    e.DB.log[#e.DB.log + 1] = "a1"; e.DB.log[#e.DB.log + 1] = "boom here"
    local at = R.Verdict(run, ctx, "a", "pass")
    T.eq(at.verdict, "fail")
    local f = io.open("build/hits-run.json", "w")
    if f then f:write(ns.Json.Encode(R.Export(run))); f:close() end
end)

test("a passing attempt with a failing diagnostic stays inside the byte budget, and a trimmed observation is marked", function()
    local run, ctx, e = mk({ { kind = "log", source = "s", contains = "ok" }, { kind = "state", probe = "global-value", name = "G", op = "eq", value = 3, diagnostic = true } })
    e.G = ("v"):rep(70)
    local old = R.EXCERPT_BUDGET; R.EXCERPT_BUDGET = 120
    for i = 1, 3 do
        ctx.now = 100 + i
        R.Begin(run, ctx, "a"); e.DB.log[#e.DB.log + 1] = "ok"
        local at = R.Verdict(run, ctx, "a", "pass")
        T.eq(at.verdict, "pass")
        run.steps.a.verdict = "pending"
    end
    R.EXCERPT_BUDGET = old
    local at = run.steps.a.attempts
    T.eq(at[1].outcomes[2].observed, nil); T.eq(at[1].outcomes[2].trimmed, true); T.eq(at[1].outcomes[2].rule:sub(1, 12), "global-value")
    T.ok(at[3].outcomes[2].observed, "the newest keeps what it saw")
end)

finish()
