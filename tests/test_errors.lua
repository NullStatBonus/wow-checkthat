local ns, test, T, finish, H = dofile("tests/harness.lua")()
local st = H.stubClient({})
H.plain(ns)

local function body(line) return (tostring(line):gsub("^%d+%.%d+ ", "")) end -- the line without its time and counter
local function bind(open, now)
    local list, t = {}, { now = now or 100, open = open ~= false }
    ns.Errors.Bind(list, function() return t.now end, function() return t.open end)
    return list, t
end

test("an error is one line while a run is open", function()
    local list = bind()
    T.eq(ns.Errors.Record("Interface\\AddOns\\X\\a.lua:3: boom"), true)
    T.eq(body(list[1]), "Interface\\AddOns\\X\\a.lua:3: boom")
    T.eq(ns.Errors.Count(), 1)
end)

test("nothing is recorded when no run is open", function()
    local list = bind(false)
    T.eq(ns.Errors.Record("boom"), false); T.eq(#list, 0)
end)

test("a message is cut, flattened and made text", function()
    local list = bind()
    ns.Errors.Record(("x"):rep(500)); T.eq(#body(list[1]), ns.Errors.LEN)
    ns.Errors.Record("a\nb\tc"); T.eq(body(list[2]), "a b c")
    ns.Errors.Record({}); T.ok(body(list[3]):find("^table:"), list[3])
    ns.Errors.Record(nil); T.eq(body(list[4]), "nil")
end)

test("the list keeps the newest lines", function()
    local list, t = bind()
    for i = 1, 250 do
        if i % 20 == 0 then t.now = t.now + 1 end
        ns.Errors.Record("e" .. i)
    end
    T.eq(#list, ns.Errors.MAX); T.eq(body(list[#list]), "e250")
end)

test("a flood is limited each second and the debug log says so once", function()
    local list, t = bind()
    local entries = {}
    ns.Log.Bind({ entries = entries, enabled = true }, function() return true end, function() return t.now end)
    for i = 1, 300 do ns.Errors.Record("e" .. i) end
    T.eq(#list, ns.Errors.RATE)
    local dropped = 0
    for _, e in ipairs(entries) do if tostring(e.msg):find("dropped errors", 1, true) then dropped = dropped + 1 end end
    T.eq(dropped, 1)
    t.now = t.now + 1
    T.eq(ns.Errors.Record("later"), true)
end)

test("the handler records and passes the error and its results on", function()
    local list = bind()
    local seen
    local h = ns.Errors.Handler(function(msg, extra) seen = { msg, extra }; return "r1", "r2" end)
    local a, b = h("boom", 7)
    T.eq(seen[1], "boom"); T.eq(seen[2], 7); T.eq(a, "r1"); T.eq(b, "r2"); T.eq(body(list[1]), "boom")
end)

test("a previous handler that raises is contained: we record, say so, and never raise in the game's handler", function()
    local list, t = bind()
    local entries = {}
    ns.Log.Bind({ entries = entries, enabled = true }, function() return true end, function() return t.now end)
    local h = ns.Errors.Handler(function(msg) error("again: " .. msg, 0) end)
    local ok, a = pcall(h, "boom")
    T.eq(ok, true, "no error escapes our handler"); T.eq(a, nil); T.eq(body(list[1]), "boom")
    local said = false
    for _, e in ipairs(entries) do if tostring(e.msg):find("previous error handler raised", 1, true) then said = true end end
    T.ok(said, "the debug log says the earlier handler raised")
end)

test("recording never raises, even when the debug log does", function()
    bind()
    local real = ns.Log.Record
    ns.Log.Record = function() error("log broke") end
    T.eq(pcall(ns.Errors.Record, "boom"), true)
    ns.Log.Record = real
end)

test("an error handler chained over ours does not record twice", function()
    local list = bind()
    local ours = ns.Errors.Handler(function() end)
    local theirs = ns.Errors.Handler(ours) -- ours placed over ours, as after a second hook
    theirs("boom")
    T.eq(#list, 1)
end)

test("the hook sets the handler once and sets it again when another addon replaced it", function()
    local list = bind()
    local sets = 0
    local realSet = _G.seterrorhandler
    _G.seterrorhandler = function(fn) sets = sets + 1; realSet(fn) end
    T.eq(ns.Errors.HookState(), "off")
    T.eq(ns.Errors.Hook(), true); T.eq(sets, 1); T.eq(ns.Errors.HookState(), "current")
    T.eq(ns.Errors.Hook(), true); T.eq(sets, 1, "still ours: nothing to set")
    local theirs = function() end
    realSet(theirs)
    T.eq(ns.Errors.HookState(), "replaced")
    T.eq(ns.Errors.Hook(), true); T.eq(sets, 2); T.eq(ns.Errors.HookState(), "current")
    local handler = _G.geterrorhandler()
    pcall(handler, "boom"); T.eq(body(list[1]), "boom", "the installed handler records")
    _G.seterrorhandler = realSet
end)

test("without error handler functions the hook does nothing and does not raise", function()
    local get, set = _G.geterrorhandler, _G.seterrorhandler
    _G.seterrorhandler = nil
    T.eq(ns.Errors.Hook(), nil)
    _G.seterrorhandler = set; _G.geterrorhandler = nil
    T.eq(ns.Errors.Hook(), nil); T.eq(ns.Errors.HookState(), "off")
    _G.geterrorhandler = get
    _G.geterrorhandler = function() error("no") end
    T.eq(ns.Errors.Hook(), nil)
    _G.geterrorhandler = get
end)

-- BugGrabber takes the one handler slot and turns seterrorhandler into a no-op (docs/contracts.md).
local function takeSlotLikeBugGrabber()
    local grab = function() end
    local realSet = _G.seterrorhandler
    realSet(grab)
    local real = realSet
    _G.seterrorhandler = function() end
    return grab, real
end
test("the debug log names the handler state when it changes, once", function()
    local list, t = bind()
    local entries = {}
    ns.Log.Bind({ entries = entries, enabled = true }, function() return true end, function() return t.now end)
    _G.seterrorhandler(function() end)
    ns.Errors.Hook(); ns.Errors.Hook()
    local n, last = 0
    for _, e in ipairs(entries) do if tostring(e.msg):find("handler ", 1, true) then n = n + 1; last = e.msg end end
    T.eq(n, 1, "unchanged state is not logged again"); T.ok(last:find("handler current", 1, true), tostring(last))
end)

test("a no-op seterrorhandler is noticed: the hook reports blocked, not set", function()
    local list = bind()
    local grab, real = takeSlotLikeBugGrabber()
    local hooked, why = ns.Errors.Hook()
    T.eq(hooked, nil); T.eq(why, "blocked"); T.eq(ns.Errors.HookState(), "blocked")
    _G.seterrorhandler = real
    T.eq(ns.Errors.Hook(), true, "once the slot can be set again, it is"); T.eq(ns.Errors.HookState(), "current")
end)

test("with the handler blocked, errors are read from BugGrabber's counters", function()
    local list, t = bind()
    local db = { BugGrabberDB = { errors = { { message = "old", counter = 4 } } } }
    ns.Errors.Bind(list, function() return t.now end, function() return true end, db)
    local grab, real = takeSlotLikeBugGrabber()
    ns.Errors.Hook()
    T.eq(ns.Errors.Sample(), 0, "the first call only takes the counters")
    db.BugGrabberDB.errors[1].counter = 6            -- a repeat of an old error: no new entry, the counter rises
    db.BugGrabberDB.errors[2] = { message = "new", counter = 1 }
    T.eq(ns.Errors.Sample(), 3)
    T.eq(body(list[1]), "old"); T.eq(body(list[2]), "old"); T.eq(body(list[3]), "new")
    T.eq(ns.Errors.Sample(), 0, "the same counters record nothing twice")
    _G.seterrorhandler = real
end)

test("sampling does nothing when our handler is current, with no run open, or without BugGrabber", function()
    local list, t = bind()
    local db = { BugGrabberDB = { errors = { { message = "x", counter = 1 } } } }
    ns.Errors.Bind(list, function() return t.now end, function() return t.open end, db)
    _G.seterrorhandler(function() end) -- some other handler; ours is set next
    ns.Errors.Hook()
    T.eq(ns.Errors.HookState(), "current")
    ns.Errors.Sample(); db.BugGrabberDB.errors[1].counter = 9
    T.eq(ns.Errors.Sample(), 0, "our handler sees errors itself")
    t.open = false
    T.eq(ns.Errors.Sample(), 0)
    ns.Errors.Bind(list, function() return t.now end, function() return true end, {})
    T.eq(ns.Errors.Sample(), 0, "no BugGrabber, nothing to read")
end)

test("rebase makes the next sample take new counters, so errors before the run do not count", function()
    local list, t = bind()
    local db = { BugGrabberDB = { errors = { { message = "x", counter = 1 } } } }
    ns.Errors.Bind(list, function() return t.now end, function() return true end, db)
    local grab, real = takeSlotLikeBugGrabber()
    ns.Errors.Hook(); ns.Errors.Sample()
    db.BugGrabberDB.errors[1].counter = 5
    ns.Errors.Rebase()
    T.eq(ns.Errors.Sample(), 0); T.eq(#list, 0)
    _G.seterrorhandler = real
end)

test("with nothing recording, judging a result records a line, so silence cannot pass", function()
    local list, t = bind()
    local real = _G.seterrorhandler
    _G.seterrorhandler = function() end      -- blocked, and no BugGrabber to read
    _G.geterrorhandler()                       -- the slot holds some other handler
    ns.Errors.Bind(list, function() return t.now end, function() return true end, {})
    T.eq(ns.Errors.Covered(), false)
    T.eq(ns.Errors.Check(), true); T.ok(list[1]:find("cannot see Lua errors", 1, true), list[1])
    _G.seterrorhandler = real
    ns.Errors.Hook()
    T.eq(ns.Errors.Covered(), true); T.eq(ns.Errors.Check(), false, "covered: nothing added")
    local db = { BugGrabberDB = { errors = {} } }
    ns.Errors.Bind(list, function() return t.now end, function() return true end, db)
    _G.seterrorhandler(function() end)         -- another addon's handler: not ours
    T.eq(ns.Errors.Covered(), true, "BugGrabber's list is readable")
end)

test("sampling compares whole snapshots: a message BugGrabber dropped starts again, and the rate limit applies to the rises", function()
    local list, t = bind()
    local db = { BugGrabberDB = { errors = { { message = "e", counter = 9 } } } }
    ns.Errors.Bind(list, function() return t.now end, function() return true end, db)
    local real = _G.seterrorhandler
    _G.seterrorhandler(function() end); _G.seterrorhandler = function() end
    ns.Errors.Hook(); ns.Errors.Sample()
    db.BugGrabberDB.errors = {}                         -- cleared
    ns.Errors.Sample()
    db.BugGrabberDB.errors = { { message = "e", counter = 1 } }  -- raised again after the clear
    T.eq(ns.Errors.Sample(), 1, "the first occurrence after a clear is seen")
    db.BugGrabberDB.errors[1].counter = 41             -- 40 rises at once
    T.eq(ns.Errors.Sample(), ns.Errors.RATE - 1, "limited to the rate, one line already used")
    _G.seterrorhandler = real
end)

test("every line is different, so a list of the same error can still show where a step began", function()
    local list, t = bind()
    for _ = 1, 4 do ns.Errors.Record("CheckThat self-test error") end
    local seen = {}
    for _, l in ipairs(list) do T.ok(not seen[l], "a repeated line: " .. l); seen[l] = true end
    T.ok(list[1]:find("^%d+%.%d+ CheckThat self%-test error$"), list[1])
    -- the absence check that was unverified in a real run (four identical lines) now has a boundary
    local plan = { logs = { q = { global = "DB", path = "errors", format = "strings", quiet = true } } }
    local a = { kind = "log", source = "q", pattern = ".", absent = true }
    local env = { DB = { errors = list } }
    local snaps = ns.Evidence.Snapshot(plan, env, { assertions = { a } })
    T.eq((ns.Evidence.CheckLog(a, snaps, plan, env)), "pass", "no new error since the step opened")
    ns.Errors.Record("later")
    T.eq((ns.Evidence.CheckLog(a, snaps, plan, env)), "fail", "an error after it opened")
end)

finish()
