-- Actions the game blocked or forbade while a run is open (#65), one line each in a bounded list in the saved variables
-- (global CheckThatDB, path global.blocked, format strings). Plans read it as a quiet log source: "nothing was blocked" is an
-- absence check, "this was blocked" a contains check. CheckThat listens for the events itself (Core/Addon.lua), so the list is
-- the same with or without BugGrabber, and Errors.Sample leaves BugGrabber's copies of these events out of the error list.
-- Data only: nothing here runs what it is given.
local _, ns = ...
local Blocked = { MAX = 50, RATE = 10 }
ns.Blocked = Blocked

-- The events, with the position of the addon name in their payload (nil: a macro, which names no addon) and of the function.
Blocked.EVENTS = {
    ADDON_ACTION_BLOCKED = { addon = 1, fn = 2 },
    ADDON_ACTION_FORBIDDEN = { addon = 1, fn = 2 },
    MACRO_ACTION_BLOCKED = { fn = 1 },
    MACRO_ACTION_FORBIDDEN = { fn = 1 },
}

local list, clock, isOpen = nil, function() return 0 end, function() return false end
local serial, win = 0, { sec = nil, n = 0, said = false }

local function note(msg) if ns.Log then pcall(ns.Log.Record, "blocked", msg) end end

function Blocked.Bind(store, clk, open)
    list = store
    clock = clk or clock
    isOpen = open or isOpen
    win = { sec = nil, n = 0, said = false }
end

local function clean(v, n)
    local s = tostring(v == nil and "?" or v):gsub("[%c%[%]]", ""):sub(1, n)
    return s ~= "" and s or "?"
end

-- Records one event: "<time>.<counter> [<addon>] <EVENT> <function>", the addon being macro for a macro event. Returns true
-- when it recorded the line. Never raises. Taint can name another addon than the one whose code ran: the line says what the
-- game said.
function Blocked.Record(event, ...)
    local shape = Blocked.EVENTS[event]
    if not (list and shape and isOpen()) then return false end
    local args = { ... }
    local who = shape.addon and clean(args[shape.addon], 40) or "macro"
    local fn = clean(args[shape.fn], 80)
    local sec = clock() or 0
    if win.sec ~= sec then win = { sec = sec, n = 0, said = false } end
    if win.n >= Blocked.RATE then
        if not win.said then win.said = true; note(("dropped blocked actions: over %d a second"):format(Blocked.RATE)) end
        return false
    end
    win.n = win.n + 1
    serial = serial + 1
    list[#list + 1] = ("%d.%03d [%s] %s %s"):format(sec, serial % 1000, who, event, fn)
    while #list > Blocked.MAX do table.remove(list, 1) end
    note(("%s %s by %s"):format(event, fn, who))
    return true
end

-- True for BugGrabber's message of one of these events ("[ADDON_ACTION_BLOCKED] AddOn 'X' tried to call ..."): it is not a Lua
-- error, and CheckThat has its own line for it.
function Blocked.IsEventMessage(msg)
    local head = tostring(msg):match("^%[([%u_]+)%]")
    return head ~= nil and Blocked.EVENTS[head] ~= nil
end

function Blocked.Count() return list and #list or 0 end
