local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local E = ns.Evidence
-- A log of { t, msg } entries keeps a time for each line; a strings log keeps none.
local plan = { logs = {
    e = { global = "DB", path = "ent", format = "entries" },
    s = { global = "DB", path = "log", format = "strings" } } }
local function env(entries, lines) return { DB = { ent = entries or {}, log = lines or {} } } end
local function ent(list)
    local out = {}
    for i, v in ipairs(list) do out[i] = { t = v[1], msg = v[2] } end
    return out
end
local function seq(items, scope) return { kind = "log-sequence", source = "e", scope = scope or "session", sequence = items } end
local function verdict(items, en, snaps, scope)
    return E.CheckSequence(seq(items, scope), snaps or {}, plan, en)
end

test("within passes when the second line came in time", function()
    T.eq((verdict({ { contains = "A" }, { contains = "B", within = 2 } }, env(ent({ { 10, "A" }, { 12, "B" } })))), "pass")
    T.eq((verdict({ { contains = "A" }, { contains = "B", within = 2 } }, env(ent({ { 10, "A" }, { 11, "B" } })))), "pass")
end)
test("within leaves a late line unverified, never a fail", function()
    local v, why = verdict({ { contains = "A" }, { contains = "B", within = 2 } }, env(ent({ { 10, "A" }, { 13, "B" } })))
    T.eq(v, "unverified")
    T.eq(why, "sequence stopped at item 2")
end)
test("within takes a later line of the same item, which leaves less time, instead of failing", function()
    T.eq((verdict({ { contains = "A" }, { contains = "B", within = 2 } }, env(ent({ { 10, "A" }, { 20, "A" }, { 21, "B" } })))), "pass")
end)
test("within pairs an item with the first line after the one before it", function()
    T.eq((verdict({ { contains = "A" }, { contains = "B", within = 1 } }, env(ent({ { 10, "A" }, { 11, "B" }, { 19, "B" } })))), "pass")
    T.eq((verdict({ { contains = "A" }, { contains = "B", within = 1 } }, env(ent({ { 10, "A" }, { 12, "B" } })))), "unverified")
end)
test("a gap that holds for three items passes", function()
    local en = env(ent({ { 10, "A" }, { 12, "B" }, { 15, "C" }, { 30, "C" } }))
    T.eq((verdict({ { contains = "A" }, { contains = "B", within = 2 }, { contains = "C", within = 3 } }, en)), "pass")
    T.eq((verdict({ { contains = "A" }, { contains = "B", within = 2 }, { contains = "C", within = 1 } }, en)), "unverified")
end)
test("a pattern too slow to run on a timed item gives the skip reason, as an untimed sequence does", function()
    ns.Pattern.ClearCache()
    local flood = string.rep("a", 400)
    local items = { { contains = "A" }, { pattern = "(%S+)%s+(.+)", within = 5 } }
    local v, why, d = E.CheckSequence(seq(items), {}, plan, env(ent({ { 10, "A" }, { 11, flood } })), true)
    T.eq(v, "unverified")
    T.eq(why, E.TOO_LONG, "the line it could not check may have matched")
    T.eq(d.unchecked, 1, "the saved detail counts it")
    local v2, why2 = E.CheckSequence(seq(items), {}, plan, env(ent({ { 10, "A" }, { 11, "x y" } })), true)
    T.eq(v2, "pass", tostring(why2))
end)
test("a log with no times cannot judge a within check", function()
    local a = { kind = "log-sequence", source = "s", scope = "session", sequence = { { contains = "A" }, { contains = "B", within = 2 } } }
    local v, why = E.CheckSequence(a, {}, plan, env(nil, { "A", "B" }))
    T.eq(v, "unverified")
    T.eq(why, "this log keeps no time for these lines, so a within check cannot be judged")
end)
test("a sequence without within needs no times", function()
    local a = { kind = "log-sequence", source = "s", scope = "session", sequence = { { contains = "A" }, { contains = "B" } } }
    T.eq((E.CheckSequence(a, {}, plan, env(nil, { "A", "B" }))), "pass")
end)
test("within reads the times of the lines after the step opened, in attempt and run scope", function()
    -- The old line's time (5) would make the gap 7 if the times were read from the start of the log.
    local items = { { contains = "A" }, { contains = "B", within = 2 } }
    local en = env(ent({ { 5, "A" }, { 10, "A" }, { 12, "B" } }))
    T.eq((verdict(items, en, { e = { n = 1, tail = { "A" }, times = { 5 } } }, "attempt")), "pass", "attempt")
    T.eq((verdict(items, en, { ["@run e"] = { n = 1, tail = { "A" }, times = { 5 } } }, "run")), "pass", "run")
    local late = env(ent({ { 5, "A" }, { 10, "A" }, { 13, "B" } }))
    T.eq((verdict(items, late, { e = { n = 1, tail = { "A" }, times = { 5 } } }, "attempt")), "unverified", "a late line in attempt scope")
end)
test("within with an inexact boundary still reads the times of the new lines", function()
    -- A tail of one repeated line, saved with no times, finds more than one place: the boundary is inexact, not the start of the log.
    local en = env(ent({ { 1, "x" }, { 2, "x" }, { 10, "A" }, { 12, "B" } }))
    local v, why = verdict({ { contains = "A" }, { contains = "B", within = 2 } }, en, { e = { n = 1, tail = { "x" } } }, "attempt")
    T.eq(v, "pass", tostring(why))
end)
test("a timed sequence stops at the first item it cannot place", function()
    local items = { { contains = "A" }, { contains = "B", within = 2 }, { contains = "C" } }
    local v, why, d = E.CheckSequence(seq(items), {}, plan, env(ent({ { 10, "B" }, { 11, "C" } })), true)
    T.eq(v, "unverified"); T.eq(why, "sequence stopped at item 1"); T.eq(d.stoppedAt, 1); T.eq(d.matched, 0)
    local _, why2, d2 = E.CheckSequence(seq(items), {}, plan, env(ent({ { 10, "A" }, { 11, "B" } })), true)
    T.eq(why2, "sequence stopped at item 3"); T.eq(d2.matched, 2)
    local _, why3, d3 = E.CheckSequence(seq(items), {}, plan, env(ent({ { 10, "A" }, { 20, "B" }, { 21, "C" } })), true)
    T.eq(why3, "sequence stopped at item 2", "B came too late"); T.eq(d3.matched, 1)
end)
test("a clock that runs back cannot pass a within check", function()
    local v, why = verdict({ { contains = "A" }, { contains = "B", within = 2 } }, env(ent({ { 100, "A" }, { 50, "B" } })))
    T.eq(v, "unverified")
    T.eq(why, "this log's clock runs back in these lines, so a within check cannot be judged")
end)
test("the detail of a timed sequence says which item stopped", function()
    local v, _, d = E.CheckSequence(seq({ { contains = "A" }, { contains = "B", within = 2 } }), {}, plan, env(ent({ { 10, "A" }, { 40, "B" } })), true)
    T.eq(v, "unverified")
    T.eq(d.stoppedAt, 2)
    T.eq(d.window, 2)
    T.eq(d.matched, 1)
end)
finish()
