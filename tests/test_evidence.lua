local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local E = ns.Evidence
local plan = { logs = {
    s = { global = "DB", path = "log", format = "strings" },
    e = { global = "DB", path = "ent", format = "entries" } } }
local function env(lines, ent) return { DB = { log = lines, ent = ent or {} } } end
test("ReadLog strings and entries", function()
    local en = env({ "a", "b" }, { { t = 1, msg = "x" }, { t = 2, msg = "y" } })
    T.eq(#E.ReadLog(plan.logs.s, en), 2)
    T.eq(E.ReadLog(plan.logs.e, en)[2], "y")
    T.ok(E.ReadLog(plan.logs.s, {}) == nil)
end)
test("NewLines handles appends, ring rollover and lost overlap", function()
    T.eq(#E.NewLines({ "a", "b", "c" }, { "a", "b", "c", "d", "e" }), 2)
    T.ok(E.NewLines({ "a", "b", "c" }, { "b", "c", "d" }) == nil, "tail cut by rollover is lost, never guessed")
    T.ok(E.NewLines({ "a", "b", "c" }, { "q", "r" }) == nil, "lost")
    T.eq(#E.NewLines({}, { "a" }), 1)
end)
test("log assertion pass, missing is unverified, absent semantics", function()
    local snaps = { s = { "old" } }
    local en = env({ "old", "[kt] started", "[kt] FAILED: x" })
    T.eq((E.CheckLog({ kind = "log", source = "s", equals = "[kt] started" }, snaps, plan, en)), "pass")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "nope" }, snaps, plan, en)), "unverified")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "FAILED", absent = true }, snaps, plan, en)), "fail")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "zzz", absent = true }, snaps, plan, en)), "pass", "window has new lines")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "old" }, snaps, plan, en)), "unverified", "stale line before attempt")
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "old", scope = "session" }, snaps, plan, en)), "pass")
end)
test("repeating startup block: boundary found by position after reload", function()
    local block = { "[blizzard] started", "[merchant] started", "[stock] FAILED: no player identity" }
    local before = {}
    for _ = 1, 2 do for _, l in ipairs(block) do before[#before + 1] = l end end
    local after = {}
    for _, l in ipairs(before) do after[#after + 1] = l end
    for _, l in ipairs(block) do after[#after + 1] = l end -- this load's block
    after[#after + 1] = "[kt] new"
    local lines = E.NewLines(before, after)
    T.eq(#lines, 4, "the third block plus the new line are new")
    -- ambiguous after a roll: same tail twice, none at the snapshot length
    T.ok(E.NewLines({ "a", "b", "c" }, { "x", "a", "b", "c", "a", "b", "c", "z" }) == nil, "ambiguous is unverified")
    -- single match after a roll is accepted
    T.eq(#E.NewLines({ "a", "b", "c" }, { "x", "y", "a", "b", "c", "q" }), 1)
end)
test("absent needs a non-empty window", function()
    local en = env({ "old" })
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "FAILED", absent = true }, { s = { "old" } }, plan, en)), "unverified")
end)
test("unreadable log is unverified", function()
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "x" }, {}, plan, {})), "unverified")
end)
test("sequence needs order", function()
    local en = env({ "off", "on 5" })
    local a = { kind = "log-sequence", source = "s", scope = "session", sequence = { { contains = "off" }, { pattern = "^on %d+" } } }
    T.eq((E.CheckSequence(a, {}, plan, en)), "pass")
    a.sequence = { { pattern = "^on" }, { contains = "off" } }
    T.eq((E.CheckSequence(a, {}, plan, en)), "unverified")
end)
test("state probes are closed and read-only", function()
    local en = { DB = { x = { y = 3 } }, IsAddOnLoaded = function(n) return n == "KT" end }
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "DB", path = "x.y", op = "gt", value = 2 }, en)), "pass")
    T.eq((E.CheckState({ kind = "state", probe = "addon-loaded", name = "KT", op = "eq", value = true }, en)), "pass")
    T.eq((E.CheckState({ kind = "state", probe = "addon-loaded", name = "ZZ", op = "eq", value = true }, en)), "fail")
    T.eq((E.CheckState({ kind = "state", probe = "run-code", op = "eq" }, en)), "unverified")
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "DB", path = "nope", op = "gt", value = 1 }, en)), "unverified")
end)
test("an unavailable probe is unverified, never false", function()
    local en = {}
    T.eq((E.CheckState({ kind = "state", probe = "addon-loaded", name = "X", op = "eq", value = false }, en)), "unverified")
    T.eq((E.CheckState({ kind = "state", probe = "frame-shown", name = "NoSuchFrame", op = "eq", value = false }, en)), "unverified")
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "DB", path = "x", op = "eq", value = false }, en)), "unverified")
    T.eq((E.CheckState({ kind = "state", probe = "global-value", name = "DB", op = "exists" }, en)), "fail")
end)
test("preview shows live check states without recording", function()
    local step = { assertions = {
        { kind = "log", source = "s", contains = "hooked", label = "Hooks started" },
        { kind = "log", source = "s", contains = "FAILED", absent = true },
        { kind = "log", source = "s", contains = "never", diagnostic = true } } }
    local snaps = { s = { "old" } }
    local en = env({ "old" })
    local items = E.Preview(step, snaps, plan, en)
    T.eq(#items, 2, "diagnostic checks are not shown")
    T.eq(items[1].state, "waiting"); T.eq(items[1].label, "Hooks started"); T.eq(items[2].state, "later")
    en.DB.log[#en.DB.log + 1] = "[kt] hooked X"
    T.eq(E.Preview(step, snaps, plan, en)[1].state, "met")
    local bad = { assertions = { { kind = "state", probe = "global-value", name = "DB", path = "log.1", op = "eq", value = "zzz" } } }
    T.eq(E.Preview(bad, {}, plan, en)[1].state, "bad")
end)
test("pattern length capped", function()
    local en = env({ "x" })
    T.eq((E.CheckLog({ kind = "log", source = "s", pattern = string.rep("a", 300) }, {}, plan, en)), "unverified")
end)

test("an unreadable log at attempt start is not an empty baseline", function()
    local snap = E.Snapshot(plan, {})                       -- addon data missing when the step opened
    T.ok(snap.s.unavailable, "marked unavailable")
    local en = env({ "old startup line" })                  -- later the log exists and holds an old line
    local r, why = E.CheckLog({ kind = "log", source = "s", contains = "old startup" }, snap, plan, en)
    T.eq(r, "unverified"); T.ok(why:find("not readable"), why)
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "old startup", scope = "session" }, snap, plan, en)), "pass")
    local empty = E.Snapshot(plan, env({}))                 -- a readable empty log is a valid baseline
    T.ok(not empty.s.unavailable)
    T.eq((E.CheckLog({ kind = "log", source = "s", contains = "new" }, empty, plan, env({ "new" }))), "pass")
end)
test("state probe keeps a stored false", function()
    local en = { DB = { flags = { on = false } } }
    local a = { kind = "state", probe = "global-value", name = "DB", path = "flags.on", op = "eq", value = false }
    T.eq((E.CheckState(a, en)), "pass")
    a.path = "flags.missing"
    T.eq((E.CheckState(a, en)), "unverified", "a missing field stays unavailable")
end)
test("frame probe survives a throwing frame", function()
    local en = setmetatable({}, { __index = function() error("boom") end })
    local a = { kind = "state", probe = "frame-shown", name = "X", op = "eq", value = true }
    T.eq((E.CheckState(a, en)), "unverified")
    en = { X = { IsShown = function() error("boom") end } }
    T.eq((E.CheckState(a, en)), "unverified")
end)

finish()
