-- Entry points that sibling addons register through CheckThat.Entry. An auto step with a "call" field names one by
-- addon and entry with literal arguments. The call runs when the step's attempt opens, outside combat, in pcall, and
-- its outcome is one fact line: "[addon] entry.<name>=<result>". Data only: the plan names a function the addon's
-- author chose to expose; it never carries code.
local _, ns = ...
local Entries = { NAME = 32, ENTRY = 42, ARGS = 8, TEXT = 100 } -- the fact key is "entry." plus the name, and a key holds 48
ns.Entries = Entries

local registry = {} -- addon -> name -> fn
local inCombat = function() return false end

-- combat() says whether the player is in combat (true when unknown).
function Entries.Bind(combat)
    inCombat = combat or inCombat
end

local function note(msg) if ns.Log then ns.Log.Record("entries", msg) end end

function Entries.ValidName(addon, name)
    return type(addon) == "string" and #addon >= 1 and #addon <= Entries.NAME and not addon:find("[^%w_%-]")
        and type(name) == "string" and #name >= 1 and #name <= Entries.ENTRY and not name:find("[^%w_%.%-]")
end

-- Allowed at any time: a run survives /reload and CheckThat loads after the addons that register (OptionalDeps), so a run can already be open.
-- An entry only runs when a plan step names it. Returns true when the entry is stored.
function Entries.Register(addon, name, fn)
    if not Entries.ValidName(addon, name) or type(fn) ~= "function" then
        note("refused an entry: the name or function is not valid"); return false
    end
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

-- True when call is {addon, entry, args}: valid names and a dense list of at most 8 texts, numbers or booleans.
function Entries.ValidCall(call)
    if type(call) ~= "table" or not Entries.ValidName(call.addon, call.entry) then return false end
    local args = call.args
    if args == nil then return true end
    if type(args) ~= "table" or #args > Entries.ARGS then return false end
    local n = 0
    for k, v in pairs(args) do
        n = n + 1
        local t = type(v)
        if type(k) ~= "number" or (t ~= "string" and t ~= "number" and t ~= "boolean") then return false end
    end
    return n == #args
end

-- Runs one call ({addon, entry, args}) and returns the text for its fact line.
function Entries.Outcome(call)
    if not Entries.ValidCall(call) then return "invalid call" end
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
    local recorded, why = true, nil
    if ns.Facts and Entries.ValidCall(call) then recorded, why = ns.Facts.Report(call.addon, "entry." .. call.entry, text) end
    note(("called %s.%s: %s%s"):format(tostring(call.addon), tostring(call.entry), text, recorded and "" or (" (fact not recorded: %s)"):format(tostring(why))))
    return text
end

-- CheckThat's own entry, so the self-test plan can check the whole path in the game with no other addon.
Entries.Register("CheckThat", "selftest.add", function(a, b) return a + b end)
