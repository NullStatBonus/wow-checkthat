-- Facts that sibling addons publish through CheckThat.Report while a run is open. A fact is one log line,
-- "[addon] key=value", in a bounded list in the saved variables. Plans read the list as an ordinary log
-- (global CheckThatDB, path global.facts, format strings). Data only: nothing here runs what it is given.
local _, ns = ...
local Facts = { MAX = 300, NAME = 32, KEY = 48, VALUE = 120, RATE = 30 }
ns.Facts = Facts

local list, clock, isOpen = nil, function() return 0 end, function() return false end
local windows = {} -- addon -> { sec = second, n = facts that second, said = limit already logged }

-- store is the saved array of lines. clk() gives whole seconds. open() says whether a run is open.
function Facts.Bind(store, clk, open)
    list = store
    clock = clk or clock
    isOpen = open or isOpen
    windows = {}
end

local function note(msg) if ns.Log then ns.Log.Record("facts", msg) end end

local function render(value)
    local t = type(value)
    if t == "boolean" then return tostring(value) end
    if t == "number" then
        if value ~= value or value == math.huge or value == -math.huge then return nil, "number is not finite" end
        return ("%.14g"):format(value)
    end
    if t == "string" then
        if #value > Facts.VALUE then return nil, "value is longer than " .. Facts.VALUE end
        if value:find("%c") then return nil, "value has a control character" end
        return value
    end
    return nil, "value is a " .. t
end

-- Returns true when the fact was recorded, false and a reason otherwise. Never raises for bad input.
function Facts.Report(addon, key, value)
    if not list or not isOpen() then return false, "no run is open" end
    if type(addon) ~= "string" or #addon < 1 or #addon > Facts.NAME or addon:find("[^%w_%-]") then
        note("dropped a fact: the addon name is not valid"); return false, "bad addon name"
    end
    if type(key) ~= "string" or #key < 1 or #key > Facts.KEY or key:find("[^%w_%.%-]") then
        note(("dropped a fact from %s: the key is not valid"):format(addon)); return false, "bad key"
    end
    local text, why = render(value)
    if not text then
        note(("dropped %s %s: %s"):format(addon, key, why)); return false, why
    end
    local sec = clock() or 0
    local w = windows[addon]
    if not w or w.sec ~= sec then w = { sec = sec, n = 0 }; windows[addon] = w end
    if w.n >= Facts.RATE then
        if not w.said then w.said = true; note(("dropped facts from %s: over %d a second"):format(addon, Facts.RATE)) end
        return false, "too many facts"
    end
    w.n = w.n + 1
    list[#list + 1] = ("[%s] %s=%s"):format(addon, key, text)
    while #list > Facts.MAX do table.remove(list, 1) end
    note(("recorded %s %s"):format(addon, key))
    return true
end

-- The table a sibling addon sees as the global CheckThat. It only grows: released names, arguments and the
-- line format stay as they are, and API_VERSION rises only when something is added.
function Facts.API()
    return {
        API_VERSION = 3,
        Entry = function(addon, name, fn)
            if not ns.Entries then return false end
            local ok, stored = pcall(ns.Entries.Register, addon, name, fn)
            return ok and stored == true
        end,
        OnRun = function(addon, fn)
            if not ns.RunEvents then return false end
            local ok, stored = pcall(ns.RunEvents.Register, addon, fn)
            return ok and stored == true
        end,
        ActiveRun = function(addon)
            if not ns.RunEvents then return nil end
            local ok, plan = pcall(ns.RunEvents.Active, addon)
            return ok and plan or nil
        end,
        Report = function(addon, key, value)
            local ok, recorded = pcall(Facts.Report, addon, key, value)
            return ok and recorded == true
        end,
    }
end

function Facts.Count() return list and #list or 0 end
function Facts.Last() return list and list[#list] or nil end
