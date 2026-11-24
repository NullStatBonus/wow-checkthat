-- Lua errors raised while a run is open, one line each in a bounded list in the saved variables
-- (global CheckThatDB, path global.errors, format strings). Plans read it as a quiet log source. Data only: nothing
-- here runs what it is given, and the handler always passes the error on to the one set before it.
local _, ns = ...
local Errors = { MAX = 100, LEN = 200, RATE = 30, STACK = 600, STACKS = 20, REHOOKS = 20 }
ns.Errors = Errors

local list, clock, isOpen, genv = nil, function() return 0 end, function() return false end, nil
local stacks -- saved array: the call stack of the first error of a step, one line each, same time and counter as its error line
local wantStack = true -- true until a stack was kept for the step that is open
local lastWatch, lostLogged, rehooks = nil, 0, 0
local lastState -- the handler state last written to the debug log
local baseline -- BugGrabber's error counters when the run opened: message -> counter
local win = { sec = nil, n = 0, said = false }
local serial = 0 -- numbers the lines of this session
local inside = false -- an error handler chained over ours calls ours again: record once

-- store is the saved array of lines. clk() gives whole seconds. open() says whether a run is open.
-- env gives read access to other addons' saved globals (Adapter.Env()).
function Errors.Bind(store, clk, open, env, stackStore)
    list, stacks = store, stackStore
    wantStack, lastWatch, lostLogged, rehooks = true, nil, 0, 0
    clock = clk or clock
    isOpen = open or isOpen
    genv = env
    baseline, lastState = nil, nil
    win = { sec = nil, n = 0, said = false }
end

local function note(msg) if ns.Log then pcall(ns.Log.Record, "errors", msg) end end

-- The addon a message names in its file path, or "?". Code that a library loads carries the library's path, not the addon's.
local function addonOf(msg)
    local name = tostring(msg):match("[Aa][Dd][Dd][Oo][Nn][Ss][\\/]([^\\/]+)[\\/]")
    if not name or name == "" then return "?" end
    return (name:gsub("[%c%[%]]", ""):sub(1, 40))
end

-- A new step wants a stack again: only the first error of a step keeps one.
function Errors.StepStarted() wantStack = true end

-- Our own handler frames come first in a stack read inside the handler. Drop them (and the pcall frames between them),
-- so the 600 characters hold the code that raised the error.
local function ownFrames(text)
    local out, leading = {}, true
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if leading and (line:find("Model/Errors%.lua", 1) or line:find("^%[C%]: in function 'pcall'")) then -- skip
        else leading = false; out[#out + 1] = line end
    end
    return table.concat(out, "\n")
end

-- stack is the call stack text, or a function that returns it (called only when this error keeps one).
local function keepStack(sec, n, stack)
    if not (stacks and wantStack) then return end
    if type(stack) == "function" then local ok, s = pcall(stack); stack = ok and type(s) == "string" and ownFrames(s) or nil end
    if type(stack) ~= "string" or stack == "" then return end
    wantStack = false
    stack = stack:gsub("%c+", " / "):sub(1, Errors.STACK)
    stacks[#stacks + 1] = ("%d.%03d %s"):format(sec, n, stack)
    while #stacks > Errors.STACKS do table.remove(stacks, 1) end
end

-- Returns true when the error was recorded. Never raises. tag overrides the addon read from the message.
function Errors.Record(msg, stack, tag)
    if not list or not isOpen() then return false end
    local who = tag or addonOf(msg)
    local text = tostring(msg):gsub("%c+", " ")
    if #text > Errors.LEN then text = text:sub(1, Errors.LEN) end
    local sec = clock() or 0
    -- Every line starts with the time and a counter, so no two lines are alike. A list of identical lines cannot show
    -- where a step began, and a check that no error appeared would stay unverified.
    serial = serial + 1
    text = ("%d.%03d [%s] %s"):format(sec, serial % 1000, who, text)
    if win.sec ~= sec then win = { sec = sec, n = 0, said = false } end
    if win.n >= Errors.RATE then
        if not win.said then win.said = true; note(("dropped errors: over %d a second"):format(Errors.RATE)) end
        return false
    end
    win.n = win.n + 1
    list[#list + 1] = text
    while #list > Errors.MAX do table.remove(list, 1) end
    pcall(keepStack, sec, serial % 1000, stack)
    note("recorded an error")
    return true
end

-- The handler to install, given the one that was set before. Its result is theirs.
function Errors.Handler(prev)
    return function(msg, ...)
        local first = not inside
        if first then
            inside = true
            pcall(Errors.Record, msg, ns.Adapter.Stack)
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
    local out, order, kept = {}, {}, {}
    for _, e in ipairs(errs) do
        if type(e) == "table" and e.message ~= nil then
            local msg = tostring(e.message)
            if out[msg] == nil then order[#order + 1] = msg end
            out[msg] = tonumber(e.counter) or 1
            if type(e.stack) == "string" then kept[msg] = e.stack end
        end
    end
    return out, order, kept
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
    return Errors.Record("CheckThat cannot see Lua errors: no error handler is set and BugGrabber is not loaded", nil, "CheckThat")
end

-- True while a run is open and nothing records errors: the card says so.
function Errors.Blind() return list ~= nil and isOpen() and not Errors.Covered() end

-- Another addon took the handler slot after us: set ours again, at most once a second. Called from the card's refresh
-- and before a result is judged. The debug log says so for the first few times only, so two addons that keep
-- replacing each other cannot flood it.
function Errors.Watch()
    if not list or not isOpen() or ns.Adapter.ErrorHookState() ~= "replaced" then return false end
    local sec = clock() or 0
    if lastWatch == sec then return false end
    if rehooks >= Errors.REHOOKS then return false end -- two addons that keep replacing each other: stop adding wrappers
    lastWatch, rehooks = sec, rehooks + 1
    if lostLogged < 5 then lostLogged = lostLogged + 1; note("another addon took the error handler: set ours again") end
    Errors.Hook()
    return true
end

function Errors.Sample()
    if not list or not isOpen() then return 0 end
    local state = ns.Adapter.ErrorHookState()
    if state == "current" then return 0 end -- our handler sees every error itself
    local now, order, kept = counters()
    if not now then return 0 end
    if not baseline then baseline = now; return 0 end
    local n = 0
    for _, msg in ipairs(order) do -- list order, so the lines come out the same every time
        for _ = 1, now[msg] - (baseline[msg] or 0) do
            if not Errors.Record(msg, kept[msg]) then break end -- the rate limit applies to the actual rises
            n = n + 1
        end
    end
    baseline = now -- a whole new snapshot: a message BugGrabber dropped starts again from nothing
    return n
end

function Errors.Count() return list and #list or 0 end
-- The newest kept stack line ("<time>.<counter> <stack>"), or nil.
function Errors.LastStack() return stacks and stacks[#stacks] or nil end
function Errors.HookState() return ns.Adapter.ErrorHookState() end
