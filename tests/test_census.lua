local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- The census walk over a fake env: no game, no frames.
H.module(ns, "Model/Census")

-- A fake env. world = { globals = { name = value }, tables = { name = { key = type } }, kinds = {...}, widgets = { kind = { methods } } }.
local function fake(world, opts)
    opts = opts or {}
    local t = { combat = false, timers = {}, clock = 0, done = 0, logged = {} }
    local env = {}
    function env.GetBuildInfo() return "1.15.9", "70576", "Nov 1 2026", 11509 end
    function env.date() return "2026-11-25" end
    function env.InCombatLockdown() return t.combat end
    function env.After(sec, fn)
        t.afters = (t.afters or 0) + 1
        if opts.noTimers or (opts.afterLimit and t.afters > opts.afterLimit) then return false end
        t.timers[#t.timers + 1] = { sec, fn }
        return true
    end
    if opts.clock then env.Clock = function() t.clock = t.clock + opts.clock; return t.clock end end
    t.reads = 0
    local function sorted(map) local k = {}; for name in pairs(map) do k[#k + 1] = name end; return k end -- in pairs order: the game does not sort
    local function after(list, cursor)
        if cursor == nil then return list[1] end
        for i, k in ipairs(list) do if k == cursor then return list[i + 1] end end
        error("invalid key to 'next'")
    end
    function env.CensusNextKey(cursor)
        t.reads = t.reads + 1
        if world.keysFail and t.reads >= world.keysFail then return false end
        t.keys = t.keys or sorted(world.globals)
        return true, after(t.keys, cursor)
    end
    function env.CensusType(name)
        t.reads = t.reads + 1
        local v = world.globals[name]
        if v == nil then return nil end
        if world.unknownSecurity then return type(v), nil end
        return type(v), not (world.addon and world.addon[name])
    end
    function env.CensusOpen(name)
        local m = world.tables[name]
        if not m then return nil end
        if world.frames and world.frames[name] then return nil, true end
        return { m = m, keys = sorted(m) }, false, not world.unknownSecurity
    end
    function env.CensusMember(h, cursor)
        t.reads = t.reads + 1
        local k = after(h.keys, cursor)
        if k == nil then return true end
        return true, k, h.m[k], true, world.unknownKey == k
    end
    function env.CensusWidgetKinds() return world.kinds or {} end
    function env.CensusWidget(kind) return world.widgets and world.widgets[kind] end
    function env.LoadedAddons() return { "CheckThat" } end
    ns.Log = { Record = function(area, msg) t.logged[#t.logged + 1] = ("[%s] %s"):format(area, msg) end }
    t.env = env
    t.db = {}
    ns.Census.Init(t.db, env)
    -- Runs the queued timers until none is left (or limit runs); returns how many ran.
    function t.pump(limit)
        local n = 0
        while #t.timers > 0 and n < (limit or 1000) do
            local timer = table.remove(t.timers, 1)
            timer[2](); n = n + 1
        end
        return n
    end
    return t
end

local function world()
    return {
        globals = { CreateFrame = function() end, MenuUtil = {}, C_AddOns = {}, Enum = {}, YES = "yes", someLower = {}, UIParent = {}, CheckThatDB = {} },
        tables = {
            C_AddOns = { GetAddOnMetadata = "function", IsAddOnLoaded = "function", ["Tester-Realm"] = "table", [1] = "number", ["has space"] = "string" },
            MenuUtil = { CreateContextMenu = "function" },
            Enum = { ItemQuality = "table" },
            UIParent = { GetObjectType = "function" },
            someLower = { X = "function" },
            CheckThatDB = {},
        },
        frames = { UIParent = true },
        kinds = { "Frame", "Cooldown", "FontString" },
        widgets = { Frame = { "SetPoint", "ClearAllPoints", "not an identifier" }, FontString = { "SetText" } },
    }
end

test("the walk records globals, tables and widgets, and stores them by build", function()
    local t = fake(world())
    T.eq(ns.Census.Start(), "started")
    T.eq(t.db.census, nil, "nothing is stored before the walk completes")
    t.pump()
    local c = t.db.census
    T.ok(c, "stored")
    T.eq(c.interface, 11509); T.eq(c.date, "2026-11-25"); T.eq(c.addons[1], "CheckThat")
    T.eq(c.globals.CreateFrame, "function"); T.eq(c.globals.YES, "string"); T.eq(c.globals.MenuUtil, "table")
    T.eq(c.tables.MenuUtil.CreateContextMenu, "function")
    T.eq(c.tables.Enum.ItemQuality, "table")
    table.sort(c.widgets.Frame) -- the game does not sort; ct.py does
    T.ok(T.deepEq(c.widgets.Frame, { "ClearAllPoints", "SetPoint" }), "c.widgets.Frame differs")
    T.ok(T.deepEq(c.widgets.FontString, { "SetText" }), "c.widgets.FontString differs")
    T.ok(T.deepEq(c.unavailable, { "Cooldown" }), "c.unavailable differs")
    T.ok(not ns.Census.Running(), "finished")
end)

test("member rules: capital names only, no frames, only identifier keys", function()
    local t = fake(world())
    ns.Census.Start(); t.pump()
    local c = t.db.census
    T.ok(T.deepEq(c.tables.C_AddOns, { GetAddOnMetadata = "function", IsAddOnLoaded = "function" }), "c.tables.C_AddOns differs")
    T.eq(c.tables.UIParent, nil, "a frame has no member list")
    T.eq(c.tables.someLower, nil, "a lower-case table is not a public table")
    T.eq(c.tables.CheckThatDB, nil, "an empty table is not listed")
    T.eq(c.globals.someLower, "table", "but it is still a global")
end)

test("the walk is chunked by the time budget", function()
    local t = fake(world(), { clock = 3 }) -- 3 ms a read: the 8 ms budget allows three steps for each frame
    ns.Census.Start()
    local frames = t.pump()
    T.ok(frames > 3, "several frames: " .. frames)
    T.ok(t.db.census, "stored at the end")
    for _, tm in ipairs(t.timers) do T.eq(tm[1], 0) end
end)

test("with no clock the walk is chunked by a step count", function()
    local w = world()
    for i = 1, 600 do w.globals["Name" .. i] = i end
    local t = fake(w)
    ns.Census.Start()
    local frames = t.pump()
    T.ok(frames >= 3, "at least three frames for 600 names: " .. frames)
    T.eq(t.db.census.globals.Name600, "number")
end)

test("it refuses to start in combat", function()
    local t = fake(world())
    t.combat = true
    T.eq(ns.Census.Start(), "combat")
    T.ok(not ns.Census.Running()); T.eq(#t.timers, 0); T.eq(#t.logged, 0)
end)

test("a second start says it is busy", function()
    local t = fake(world())
    T.eq(ns.Census.Start(), "started"); T.eq(ns.Census.Start(), "busy")
end)

test("combat pauses the walk and the end of combat resumes it", function()
    local t = fake(world(), { clock = 3 })
    ns.Census.Start()
    t.pump(2)
    t.combat = true
    t.pump(3)
    T.ok(ns.Census.Running(), "still waiting")
    T.eq(t.db.census, nil, "nothing stored while paused")
    local paused = 0
    for _, l in ipairs(t.logged) do if l == "[census] paused for combat" then paused = paused + 1 end end
    T.eq(paused, 1, "the pause is logged once")
    t.combat = false
    ns.Census.Resume()
    t.pump()
    T.ok(t.db.census, "complete after combat")
    T.eq(t.logged[1], "[census] started 1.15.9.70576")
    T.eq(t.logged[#t.logged], "[census] done 1.15.9.70576 8 globals 3 tables 2 widget types 0 addon")
end)

test("the next tick out of combat resumes without the event", function()
    local t = fake(world(), { clock = 3 })
    ns.Census.Start(); t.pump(2)
    t.combat = true; t.pump(1)
    t.combat = false
    t.pump()
    T.ok(t.db.census)
end)

test("a finished census replaces the stored one of any build; an unfinished one does not", function()
    local t = fake(world(), { clock = 3 })
    t.db.census = { old = true, build = "0.0.0.1" }
    ns.Census.Start(); t.pump(3)
    T.ok(t.db.census.old, "the old census stays until the walk completes")
    t.pump()
    T.eq(t.db.census.old, nil); T.eq(t.db.census.build, "1.15.9.70576")
    T.eq(t.db.census["1.15.9.70576"], nil, "one record, not one for each build")
end)

test("a census saved by the per-build format is dropped at Init", function()
    local t = fake(world())
    t.db.census = { ["1.15.9.70576"] = { globals = {} } }
    ns.Census.Init(t.db, t.env)
    T.eq(t.db.census, nil)
    t.db.census = { build = "x", globals = {} }
    ns.Census.Init(t.db, t.env)
    T.ok(t.db.census, "the current format stays")
end)

test("globals that an addon defined are not recorded and are counted in the log", function()
    local w = world()
    w.globals.SomeAddonGlobal = {}; w.globals.AddonData = 1
    w.addon = { SomeAddonGlobal = true, AddonData = true, CheckThatDB = true }
    w.tables.SomeAddonGlobal = { Secret = "function" }
    local t = fake(w)
    ns.Census.Start(); t.pump()
    local c = t.db.census
    T.eq(c.globals.SomeAddonGlobal, nil); T.eq(c.globals.AddonData, nil); T.eq(c.globals.CheckThatDB, nil)
    T.eq(c.insecure.SomeAddonGlobal, "table", "kept apart with its type"); T.eq(c.insecure.AddonData, "number")
    T.eq(c.tables.SomeAddonGlobal, nil, "an addon table is not walked")
    T.eq(c.unfiltered, nil, "the client could tell")
    T.eq(t.logged[#t.logged], "[census] done 1.15.9.70576 7 globals 3 tables 2 widget types 3 addon")
end)

test("a client that cannot tell the game's names is marked unfiltered and keeps every name", function()
    local w = world(); w.unknownSecurity = true
    local t = fake(w)
    ns.Census.Start(); t.pump()
    T.eq(t.db.census.unfiltered, true); T.eq(t.db.census.globals.CheckThatDB, "table")
    T.ok(t.logged[#t.logged]:find(" unfiltered$"), t.logged[#t.logged])
end)

test("a table that was cut at the member cap is recorded as truncated", function()
    local cap = ns.Census.MEMBER_CAP
    ns.Census.MEMBER_CAP = 2
    local t = fake(world())
    ns.Census.Start(); t.pump()
    ns.Census.MEMBER_CAP = cap
    T.ok(T.deepEq(t.db.census.truncated, { "C_AddOns" }), "only the table over the cap is cut")
    local t2 = fake(world()); ns.Census.Start(); t2.pump()
    T.eq(t2.db.census.truncated, nil)
end)

test("the names are not sorted in the game", function()
    local t = fake(world())
    local sort = table.sort
    local calls = 0
    table.sort = function(...) calls = calls + 1; return sort(...) end
    ns.Census.Start(); t.pump()
    table.sort = sort
    T.eq(calls, 0)
end)

test("a timer left over after Resume finished the walk does nothing", function()
    local t = fake(world())
    ns.Census.Start()
    t.combat = true; t.pump(1) -- paused: a retry timer is queued
    t.combat = false
    ns.Census.Resume()
    T.ok(t.db.census, "Resume finished the walk")
    T.ok(#t.timers > 0, "a timer is still queued")
    local ok, err = pcall(t.pump)
    T.ok(ok, tostring(err)); T.eq(#t.timers, 0)
end)

test("a second census does not start a second timer chain", function()
    local w = world()
    for i = 1, 600 do w.globals["Pad" .. i] = i end -- more than one frame of work
    local t = fake(w)
    ns.Census.Start()
    t.combat = true; t.pump(1) -- paused: a retry timer is queued
    t.combat = false
    ns.Census.Resume() -- carries on; the retry timer stays queued
    while ns.Census.Running() do ns.Census.Tick() end -- finish without the timers
    local stale = #t.timers
    T.ok(stale >= 1, "a timer is left over")
    t.timers = { t.timers[1] }
    stale = 1
    T.eq(ns.Census.Start(), "started")
    T.eq(#t.timers, 2, "the new walk queues one timer")
    t.pump(1) -- the old walk's timer runs first
    T.eq(#t.timers, 1, "it did nothing")
    while ns.Census.Running() do
        t.pump(1)
        T.ok(#t.timers <= 1, "one chain: " .. #t.timers)
    end
    T.ok(t.db.census)
end)

test("the done callback runs once at the end", function()
    local t = fake(world())
    local n = 0
    ns.Census.Start(function() n = n + 1 end)
    T.eq(n, 0); t.pump(); T.eq(n, 1)
    T.eq(ns.Census.Start(), "started", "a new walk can start")
end)

test("a key list that cannot be read stops the walk, keeps the saved census and says so", function()
    local w = world(); w.keysFail = 3
    local t = fake(w)
    t.db.census = { old = true, globals = {} }
    local failed = 0
    T.eq(ns.Census.Start(nil, function() failed = failed + 1 end), "started")
    t.pump()
    T.eq(failed, 1); T.ok(t.db.census.old, "the saved census is unchanged")
    T.ok(not ns.Census.Running(), "not busy")
    T.eq(t.logged[#t.logged], "[census] failed names unreadable")
    T.eq(ns.Census.Start(), "started", "a new census can start")
end)

test("reads are counted: no frame reads more than the budget, whatever the table size", function()
    local w = world()
    local big = {}
    for i = 1, 3000 do big["K" .. i] = "number" end
    w.globals.Huge = {}; w.tables.Huge = big
    for i = 1, 700 do w.globals["N" .. i] = i end
    local t = fake(w)
    local worst, last = 0, 0
    ns.Census.Start()
    while #t.timers > 0 do
        t.pump(1)
        worst = math.max(worst, t.reads - last); last = t.reads
    end
    T.ok(worst <= ns.Census.BUDGET_READS, "reads in one frame: " .. worst)
    T.ok(t.db.census, "stored")
    T.ok(T.deepEq(t.db.census.truncated, { "Huge" }), "cut at the member cap")
    local n = 0; for _ in pairs(t.db.census.tables.Huge) do n = n + 1 end
    T.eq(n, ns.Census.MEMBER_CAP)
end)

test("a client with no timers walks in one pass and is never busy", function()
    local t = fake(world(), { noTimers = true })
    local done = 0
    T.eq(ns.Census.Start(function() done = done + 1 end), "started")
    T.eq(done, 1); T.ok(t.db.census, "stored"); T.ok(not ns.Census.Running(), "not busy")
    local t2 = fake(world(), { noTimers = true })
    t2.combat = false
    local env = t2.env
    local c = env.InCombatLockdown
    local calls = 0
    env.InCombatLockdown = function() calls = calls + 1; return calls > 5 end -- combat starts mid-pass
    ns.Census.Start()
    T.ok(not ns.Census.Running(), "stopped by combat, not busy")
    T.eq(t2.db.census, nil)
end)

test("a timer that fails mid-walk finishes the walk in one pass", function()
    local w = world()
    for i = 1, 600 do w.globals["Q" .. i] = i end
    local t = fake(w, { afterLimit = 1 }) -- the first timer works, the next one is refused
    ns.Census.Start(); t.pump()
    T.ok(t.db.census, "finished"); T.ok(not ns.Census.Running())
end)

test("a member with no answer on a real key marks the census unfiltered", function()
    local w = world(); w.unknownKey = "GetAddOnMetadata"
    local t = fake(w)
    ns.Census.Start(); t.pump()
    T.eq(t.db.census.unfiltered, true)
    T.eq(t.db.census.tables.C_AddOns.GetAddOnMetadata, "function", "the member is kept")
end)

finish()
