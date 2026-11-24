-- Lua errors raised while a run is open, one line each in a bounded list in the saved variables
-- (global CheckThatDB, path global.errors, format strings). Plans read it as a quiet log source. Data only: nothing
-- here runs what it is given, and the handler always passes the error on to the one set before it.
local _, ns = ...
local Errors = { MAX = 100, LEN = 200, RATE = 30 }
ns.Errors = Errors

local list, clock, isOpen, genv = nil, function() return 0 end, function() return false end, nil
local lastState -- the handler state last written to the debug log
local baseline -- BugGrabber's error counters when the run opened: message -> counter
local win = { sec = nil, n = 0, said = false }
local serial = 0 -- numbers the lines of this session
local inside = false -- an error handler chained over ours calls ours again: record once

-- store is the saved array of lines. clk() gives whole seconds. open() says whether a run is open.
-- env gives read access to other addons' saved globals (Adapter.Env()).
function Errors.Bind(store, clk, open, env)
    list = store
    clock = clk or clock
    isOpen = open or isOpen
    genv = env
    baseline, lastState = nil, nil
    win = { sec = nil, n = 0, said = false }
end

local function note(msg) if ns.Log then pcall(ns.Log.Record, "errors", msg) end end

-- Returns true when the error was recorded. Never raises.
function Errors.Record(msg)
    if not list or not isOpen() then return false end
    local text = tostring(msg):gsub("%c+", " ")
    if #text > Errors.LEN then text = text:sub(1, Errors.LEN) end
    local sec = clock() or 0
    -- Every line starts with the time and a counter, so no two lines are alike. A list of identical lines cannot show
    -- where a step began, and a check that no error appeared would stay unverified.
    serial = serial + 1
    text = ("%d.%03d %s"):format(sec, serial % 1000, text)
    if win.sec ~= sec then win = { sec = sec, n = 0, said = false } end
    if win.n >= Errors.RATE then
        if not win.said then win.said = true; note(("dropped errors: over %d a second"):format(Errors.RATE)) end
        return false
    end
    win.n = win.n + 1
    list[#list + 1] = text
    while #list > Errors.MAX do table.remove(list, 1) end
    note("recorded an error")
    return true
end

-- The handler to install, given the one that was set before. Its result is theirs.
function Errors.Handler(prev)
    return function(msg, ...)
        local first = not inside
        if first then
            inside = true
            pcall(Errors.Record, msg)
        end
        local ok, a, b, c = pcall(function(...) if prev then return prev(msg, ...) end end, ...)
        if first then inside = false end
        if not ok then note("the previous error handler raised an error"); return end -- never raise inside the game's handler
        return a, b, c
    end
end

-- Puts our handler first in the chain, unless it still is. Safe to call again: at run start and on trigger.
function Errors.Hook()
    local hooked, why = ns.Adapter.HookErrors(Errors.Handler)
    local state = ns.Adapter.ErrorHookState()
    if state ~= lastState then lastState = state; note("handler " .. state) end -- so a saved log says which way errors were read
    return hooked, why
end

-- When the handler cannot be set (BugGrabber took the slot), read BugGrabber's list instead. It folds a repeated error
-- into one entry and counts it, so a new error is a counter that went up. The first call after Rebase only takes the
-- counters. Call it before a step opens and before a result is judged. Returns how many errors it recorded.
local function counters()
    local db = genv and genv.BugGrabberDB
    local errs = type(db) == "table" and db.errors
    if type(errs) ~= "table" then return nil end
    local out, order = {}, {}
    for _, e in ipairs(errs) do
        if type(e) == "table" and e.message ~= nil then
            local msg = tostring(e.message)
            if out[msg] == nil then order[#order + 1] = msg end
            out[msg] = tonumber(e.counter) or 1
        end
    end
    return out, order
end

function Errors.Rebase() baseline = nil end

-- Is something recording errors right now: our handler, or BugGrabber's list we can read?
function Errors.Covered()
    if ns.Adapter.ErrorHookState() == "current" then return true end
    return counters() ~= nil
end

-- Called when a result is judged. With nothing recording, an empty list proves nothing: one line says so, in the
-- window of the step, so a check that no error appeared cannot pass on silence.
function Errors.Check()
    if not list or not isOpen() or Errors.Covered() then return false end
    return Errors.Record("CheckThat cannot see Lua errors: no error handler is set and BugGrabber is not loaded")
end

function Errors.Sample()
    if not list or not isOpen() then return 0 end
    local state = ns.Adapter.ErrorHookState()
    if state == "current" then return 0 end -- our handler sees every error itself
    local now, order = counters()
    if not now then return 0 end
    if not baseline then baseline = now; return 0 end
    local n = 0
    for _, msg in ipairs(order) do -- list order, so the lines come out the same every time
        for _ = 1, now[msg] - (baseline[msg] or 0) do
            if not Errors.Record(msg) then break end -- the rate limit applies to the actual rises
            n = n + 1
        end
    end
    baseline = now -- a whole new snapshot: a message BugGrabber dropped starts again from nothing
    return n
end

function Errors.Count() return list and #list or 0 end
function Errors.HookState() return ns.Adapter.ErrorHookState() end
