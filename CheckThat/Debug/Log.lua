-- Bounded debug log, and the text of /ct log. Lines are "[area] message". State lives in a table the
-- caller binds (the saved global.log) so tests need no game.
local _, ns = ...

local Log = { MAX = 300, failures = {} }
ns.Log = Log

local store, enabled, clock = nil, function() return false end, function() return 0 end

-- store = { entries = {...} }; isEnabled() says whether recording is on; clk() gives the time.
function Log.Bind(s, isEnabled, clk)
    store = s
    store.entries = store.entries or {}
    enabled = isEnabled or enabled
    clock = clk or clock
end

function Log.Enabled() return store ~= nil and enabled() and true or false end

function Log.Record(area, message)
    if not store or not enabled() then return end
    local e = store.entries
    e[#e + 1] = { t = clock() or 0, msg = ("[%s] %s"):format(tostring(area), tostring(message)) }
    while #e > Log.MAX do table.remove(e, 1) end
end

-- A failure that turned something off for the session. Kept for the report even when recording is off.
function Log.Failure(area, message)
    Log.failures[#Log.failures + 1] = { area = tostring(area), message = tostring(message) }
    Log.Record(area, "FAILED: " .. tostring(message))
end

function Log.Entries() return store and store.entries or {} end

-- Clears the recorded lines and failures only. Plans, runs and settings stay.
function Log.Clear()
    if store then store.entries = {} end
    Log.failures = {}
end

local function flatten(t, prefix, out)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) then return a < b end
        return type(a) < type(b)
    end)
    for _, k in ipairs(keys) do
        local v, path = t[k], prefix .. tostring(k)
        if type(v) == "table" then flatten(v, path .. ".", out)
        else out[#out + 1] = ("  %s = %s"):format(path, tostring(v)) end
    end
end

-- The report text. English only (debug output is not translated).
function Log.Report()
    local out = { ("CheckThat %s, client %s, build %s"):format(tostring(ns.version),
        ns.App and ns.App.Client() or "?", ns.App and ns.App.Build() or "?"), "", "Settings:" }
    local db = ns.addon and ns.addon.db
    if db then
        out[#out + 1] = "  profile = " .. tostring(ns.Settings.ProfileName())
        flatten(db.profile, "", out)
    end
    out[#out + 1] = "  presentation contract = v1"
    out[#out + 1] = ""
    out[#out + 1] = "Run: " .. (ns.App and ns.App.db and ns.App.Status() or "none")
    if ns.App and ns.App.db then
        local _, ctx = ns.App.Current()
        if ctx then
            local reads = ns.App.PlanReads(ctx.plan)
            out[#out + 1] = "Plan reads: " .. (#reads > 0 and table.concat(reads, ", ") or "none")
            local offered, missing = ns.App.CommandsCheck(ctx.plan)
            if #offered + #missing > 0 then
                out[#out + 1] = ("Plan commands: offered %s; not offered %s"):format(#offered > 0 and table.concat(offered, ", ") or "none", #missing > 0 and table.concat(missing, ", ") or "none")
            end
        end
    end
    if ns.App and ns.App.db then
        local runs, plans = 0, 0
        for _ in pairs(ns.App.db.runs) do runs = runs + 1 end
        for _ in pairs(ns.App.db.planStore) do plans = plans + 1 end
        local stored = ("Stored: %d runs (limit %d), %d plan copies"):format(runs, ns.App.RunLimit(), plans)
        out[#out + 1] = stored
        local rev = ns.App.db.dbRev
        out[#out + 1] = ("Saved data: rev %s%s"):format(tostring(rev), type(rev) == "number" and rev > ns.App.DB_REV and (" (newer than this version's %d, left as it is)"):format(ns.App.DB_REV) or "")
        local newer = ns.App.FutureCount()
        out[#out + 1] = ("Run format: ct %d, revision %d, written by %s%s"):format(ns.Run.MAJOR, ns.Run.FORMAT_REV, tostring(ns.version),
            newer > 0 and (", %d saved run(s) from a newer CheckThat kept untouched"):format(newer) or "")
        if ns.Facts then out[#out + 1] = ("Facts: %d, last: %s"):format(ns.Facts.Count(), ns.Facts.Last() or "none") end
        local rows, overall = ns.App.Categories()
        if rows then
            out[#out + 1] = "Categories: overall " .. overall
            for _, r in ipairs(rows) do
                out[#out + 1] = ("  %s: %s%s, %d of %d done"):format(r.id, r.state, r.picked and "" or " (not picked)", r.counts.resolved, r.counts.total)
            end
        end
        if ns.Errors then
            out[#out + 1] = ("Errors: %d recorded, handler: %s"):format(ns.Errors.Count(), ns.Errors.HookState())
            if ns.Blocked then out[#out + 1] = ("Blocked actions: %d recorded"):format(ns.Blocked.Count()) end
            local stack = ns.Errors.LastStack()
            if stack then out[#out + 1] = "Last error stack: " .. stack end
        end
        ns.App.Log("report requested: " .. stored)
    end
    out[#out + 1] = ""
    out[#out + 1] = "Failures:"
    if #Log.failures == 0 then out[#out + 1] = "  none" end
    for _, f in ipairs(Log.failures) do out[#out + 1] = ("  [%s] %s"):format(f.area, f.message) end
    out[#out + 1] = ""
    out[#out + 1] = ("Log (%s, last %d lines):"):format(Log.Enabled() and "recording" or "recording off", Log.MAX)
    for _, e in ipairs(Log.Entries()) do out[#out + 1] = ("[%.0f] %s"):format(e.t or 0, e.msg) end
    return table.concat(out, "\n")
end
