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
local function seq(items) return { kind = "log-sequence", source = "e", scope = "session", sequence = items } end
local function verdict(items, en, snaps)
    return E.CheckSequence(seq(items), snaps or {}, plan, en)
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
test("within reads the times of the lines after the step opened", function()
    local en = env(ent({ { 5, "old" }, { 10, "A" }, { 12, "B" } }))
    local snaps = { e = { n = 1, tail = { "old" }, times = { 5 } } }
    T.eq((verdict({ { contains = "A" }, { contains = "B", within = 2 } }, en, snaps)), "pass")
end)
test("the detail of a timed sequence says which item stopped", function()
    local v, _, d = E.CheckSequence(seq({ { contains = "A" }, { contains = "B", within = 2 } }), {}, plan, env(ent({ { 10, "A" }, { 40, "B" } })), true)
    T.eq(v, "unverified")
    T.eq(d.stoppedAt, 2)
    T.eq(d.window, 2)
    T.eq(d.matched, 1)
end)
finish()
