-- Entry points that sibling addons register through CheckThat.Entry. An auto step with a "call" field names one by
-- addon and entry with literal arguments. The call runs when the step's attempt opens, outside combat, in pcall, and
-- its outcome is one fact line: "[addon] entry.<name>=<result>". Data only: the plan names a function the addon's
-- author chose to expose; it never carries code.
local _, ns = ...
local Entries = { NAME = 32, ENTRY = 42, ARGS = 8, TEXT = 100 } -- the fact key is "entry." plus the name, and a key holds 48
ns.Entries = Entries

local registry = {} -- addon -> name -> fn
local isOpen, inCombat = function() return false end, function() return false end

-- open() says whether a run is open; combat() whether the player is in combat.
function Entries.Bind(open, combat)
    isOpen = open or isOpen
    inCombat = combat or inCombat
end

local function note(msg) if ns.Log then ns.Log.Record("entries", msg) end end

function Entries.ValidName(addon, name)
    return type(addon) == "string" and #addon >= 1 and #addon <= Entries.NAME and not addon:find("[^%w_%-]")
        and type(name) == "string" and #name >= 1 and #name <= Entries.ENTRY and not name:find("[^%w_%.%-]")
end

-- Allowed at addon load, before a run opens. Returns true when the entry is stored.
function Entries.Register(addon, name, fn)
    if not Entries.ValidName(addon, name) or type(fn) ~= "function" then
        note("refused an entry: the name or function is not valid"); return false
    end
    if isOpen() then note(("refused entry %s.%s: a run is open"):format(addon, name)); return false end
    registry[addon] = registry[addon] or {}
    registry[addon][name] = fn
    note(("registered %s.%s"):format(addon, name))
    return true
end

function Entries.Has(addon, name) return registry[addon] ~= nil and registry[addon][name] ~= nil end

local function show(v)
    local t = type(v)
    if t == "string" then return (v:gsub("%c", " ")) end
    if t == "number" or t == "boolean" or t == "nil" then return tostring(v) end
    return "<" .. t .. ">"
end

local function cut(s) return #s > Entries.TEXT and s:sub(1, Entries.TEXT - 3) .. "..." or s end

-- Runs one call ({addon, entry, args}) and returns the text for its fact line.
function Entries.Outcome(call)
    local fn = registry[call.addon] and registry[call.addon][call.entry]
    if not fn then return "not registered" end
    if inCombat() then return "refused: in combat" end
    local args = call.args or {}
    local function pack(...) return { n = select("#", ...), ... } end
    local r = pack(pcall(fn, unpack(args, 1, #args)))
    if not r[1] then return cut("threw: " .. show(r[2])) end
    if r.n == 1 then return "(none)" end
    local parts = {}
    for i = 2, r.n do parts[#parts + 1] = show(r[i]) end
    return cut(table.concat(parts, ","))
end

-- Calls the entry and reports the outcome as a fact. Returns the text.
function Entries.Run(call)
    local text = Entries.Outcome(call)
    if ns.Facts then ns.Facts.Report(call.addon, "entry." .. call.entry, text) end
    note(("called %s.%s: %s"):format(call.addon, call.entry, text))
    return text
end

-- CheckThat's own entry, so the self-test plan can check the whole path in the game with no other addon.
Entries.Register("CheckThat", "selftest.add", function(a, b) return a + b end)
