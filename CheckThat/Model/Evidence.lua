-- Read-only evidence: addon debug logs and state probes. Never writes to another addon's data.
local _, ns = ...
local Evidence = {}
ns.Evidence = Evidence

local MAX_PATTERN = 200
Evidence.TAIL = 12 -- lines of a log kept as the position where an attempt opened

local function walk(root, path)
    local v = root
    for part in tostring(path or ""):gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part] ~= nil and v[part] or v[tonumber(part) or part]
    end
    return v
end
Evidence.walk = walk

-- A log source is { global = "KeepThatDB", path = "global.log", format = "strings"|"entries" }.
-- Returns an array of message strings, or nil when the log cannot be read.
function Evidence.ReadLog(src, env)
    env = env or _G
    local root = env[src.global]
    if type(root) ~= "table" then return nil end
    local list = walk(root, src.path)
    if type(list) ~= "table" then return nil end
    local out = {}
    for i, e in ipairs(list) do
        if src.format == "entries" then out[i] = type(e) == "table" and tostring(e.msg) or tostring(e)
        else out[i] = tostring(e) end
    end
    return out
end

-- Lines added after the snapshot. Logs repeat the same startup block each session, so find the boundary by
-- position: if the snapshot tail sits exactly at the snapshot length, nothing rolled and the boundary is there.
-- Otherwise (ring rolled) accept a single match; several matches are ambiguous. Returns array, or nil when the
-- boundary cannot be located (treat as unverified).
-- cap is how many lines the log keeps, when the plan says (a bounded list that drops the oldest line at the cap).
function Evidence.NewLines(snapshot, current, cap)
    if not current then return nil end
    if snapshot and snapshot.unavailable then return nil end -- the log could not be read when the step opened
    if not snapshot then return current, true end
    -- A position is { n = length, tail = last lines }; runs saved before it hold the whole log as an array.
    local n = snapshot.tail and snapshot.n or #snapshot
    local tail = snapshot.tail or snapshot
    if not n or n == 0 then return current, true end
    local k = math.min(Evidence.TAIL, n) -- a long tail: startup blocks repeat every session, so a short one is ambiguous
    local tl = #tail
    local function tailAt(last)
        if last < k or last > #current or tl < k then return false end
        for j = 1, k do if current[last - k + j] ~= tail[tl - k + j] then return false end end
        return true
    end
    local last = nil
    if tailAt(n) then last = n
    else
        local found = 0
        for i = k, #current do
            if tailAt(i) then found = found + 1; last = i end
        end
        if found ~= 1 then return nil end
    end
    -- A full ring rolls with every new line, so a boundary found by search is normal. It holds when the tail is
    -- distinctive. A tail made of one repeated line (a flood) can also match lines written after the step opened,
    -- and then a line between could be missed: an absence cannot be shown.
    local seen, distinct = {}, 0
    for j = 1, k do
        local l = tail[tl - k + j]
        if not seen[l] then seen[l] = true; distinct = distinct + 1 end
    end
    local exact = distinct >= math.ceil(k / 2)
    -- A log that keeps cap lines and holds fewer has never dropped one, so a boundary at the snapshot position is
    -- certain, however alike the lines are.
    if not exact and cap and last == n and #current < cap then exact = true end
    local out = {}
    for i = last + 1, #current do out[#out + 1] = current[i] end
    return out, exact
end

-- An attempt that has positions but none for this source cannot say which lines are new.
local function missingPosition(a, snapshots)
    return a.scope ~= "session" and snapshots ~= nil and snapshots[a.source] == nil
end

local function lineMatches(a, line)
    if a.equals then return line == a.equals end
    if a.contains then return line:find(a.contains, 1, true) ~= nil end
    if a.pattern then
        if #a.pattern > MAX_PATTERN then return false end
        local ok, r = pcall(string.find, line, a.pattern)
        return ok and r ~= nil
    end
    return false
end

-- The new lines of a source for an assertion: scope session reads the whole log. Returns lines and whether the
-- boundary is exact, or nil and the reason the log cannot be judged.
local function window(a, snapshots, plan, env)
    local src = plan.logs and plan.logs[a.source]
    if not src then return nil, "unknown log source" end
    local current = Evidence.ReadLog(src, env)
    if not current then return nil, "log not readable (is debug on and the addon loaded?)" end
    if a.scope == "session" then return current, true, src end
    if missingPosition(a, snapshots) then return nil, "log position missing (the step opened without it)" end
    if snapshots and snapshots[a.source] and snapshots[a.source].unavailable then return nil, "log was not readable when the step opened" end
    local lines, exact = Evidence.NewLines(snapshots and snapshots[a.source], current, src.cap)
    if not lines then return nil, "log rolled over; evidence lost" end
    return lines, exact, src
end

-- How many matched against a count. Too many fails. Too few is unverified, as the line can still arrive. A count
-- that allows none follows the rules of an absence check: the log must be readable with a known boundary, and
-- a log that is not quiet must show some new line, or it may simply be off.
local function judgeCount(n, c, lines, exact, src, a)
    local lo = c.exactly or c.min or 0
    local hi = c.exactly or c.max or math.huge
    if n > hi then return "fail", ("%d matched, at most %d allowed"):format(n, hi) end
    if n < lo then return "unverified", ("%d matched, %d needed"):format(n, lo) end
    -- A boundary that is not exact may have hidden lines. An upper bound cannot be shown then.
    if hi ~= math.huge and a.scope ~= "session" and exact == false then return "unverified", "log rolled over; a count cannot be shown" end
    if n == 0 then
        if a.scope ~= "session" and exact == false then return "unverified", "log rolled over; a line that is absent cannot be shown" end
        if #lines == 0 and not (src and src.quiet) then return "unverified", "no new log lines (is debug on?)" end
    end
    return "pass"
end

-- Result: "pass" | "fail" | "unverified"
function Evidence.CheckLog(a, snapshots, plan, env)
    local lines, exact, src = window(a, snapshots, plan, env)
    if not lines then return "unverified", exact end
    if a.count then
        local n = 0
        for _, l in ipairs(lines) do if lineMatches(a, l) then n = n + 1 end end
        return judgeCount(n, a.count, lines, exact, src, a)
    end
    if a.absent and a.scope ~= "session" and exact == false then
        for _, l in ipairs(lines) do if lineMatches(a, l) then return "fail" end end
        return "unverified", "log rolled over; a line that is absent cannot be shown"
    end
    local found
    for _, l in ipairs(lines) do if lineMatches(a, l) then found = true; break end end
    if a.absent then
        if found then return "fail" end
        if #lines == 0 and not src.quiet then return "unverified", "no new log lines (is debug on?)" end
        return "pass"
    end
    if found then return "pass" end
    return "unverified", "no matching log line"
end

-- A fact is stored as the line "[addon] key=value". The value reads as a boolean, a number, or else text.
function Evidence.ParseValue(text)
    if text == "true" then return true elseif text == "false" then return false end
    if text:match("^%-?%d+%.?%d*$") or text:match("^%-?%.%d+$") or text:match("^%-?%d*%.?%d+[eE][%+%-]?%d+$") then
        local n = tonumber(text)
        if n then return n end
    end
    return text
end

function Evidence.ParseFact(line)
    local addon, key, text = tostring(line):match("^%[([^%]]*)%] ([^=]+)=(.*)$")
    if not addon then return nil end
    return addon, key, Evidence.ParseValue(text)
end

-- Operators over a value x (from a probe or a fact), the plan's value v and the assertion a.
local function isnum(x) return type(x) == "number" end
local ops = {
    eq = function(x, v) return x == v end,
    ne = function(x, v) return x ~= v end,
    gt = function(x, v) return isnum(x) and isnum(v) and x > v end,
    ge = function(x, v) return isnum(x) and isnum(v) and x >= v end,
    lt = function(x, v) return isnum(x) and isnum(v) and x < v end,
    le = function(x, v) return isnum(x) and isnum(v) and x <= v end,
    contains = function(x, v) return type(x) == "string" and type(v) == "string" and x:find(v, 1, true) ~= nil end,
    exists = function(x) return x ~= nil end,
    missing = function(x) return x == nil end,
    between = function(x, v) return isnum(x) and type(v) == "table" and isnum(v[1]) and isnum(v[2]) and x >= v[1] and x <= v[2] end,
    approx = function(x, v, a) return isnum(x) and isnum(v) and isnum(a.tolerance) and math.abs(x - v) <= a.tolerance end,
    matches = function(x, v)
        if type(x) ~= "string" or type(v) ~= "string" or #v > MAX_PATTERN then return false end
        local ok, r = pcall(string.find, x, v)
        return ok and r ~= nil
    end,
    type = function(x, v) return type(x) == v end,
    ["in"] = function(x, v)
        if type(v) ~= "table" then return false end
        for _, e in ipairs(v) do if e == x then return true end end
        return false
    end,
}
Evidence.Ops = ops

-- Closed registry of read-only probes. env supplies the game (or a fake).
function Evidence.Probe(a, env)
    env = env or _G
    if a.probe == "addon-loaded" then
        local f = env.IsAddOnLoaded or (env.C_AddOns and env.C_AddOns.IsAddOnLoaded)
        if not f then return nil end
        local r = f(a.name)
        if r == nil then return nil end
        return r and true or false
    elseif a.probe == "global-value" then
        local root = env[a.name]
        if a.path == nil then return root end
        if type(root) ~= "table" then return nil end
        return walk(root, a.path) -- a stored false stays false
    elseif a.probe == "frame-shown" then
        local ok, shown = pcall(function()
            local f = env[a.name]
            if type(f) ~= "table" or type(f.IsShown) ~= "function" then return nil end
            return f:IsShown() and true or false
        end)
        if not ok then return nil end
        return shown
    end
end

-- Ordered matches: each item must appear after the previous one in the attempt window.
function Evidence.CheckSequence(a, snapshots, plan, env)
    local src = plan.logs and plan.logs[a.source]
    if not src then return "unverified", "unknown log source" end
    local current = Evidence.ReadLog(src, env)
    if not current then return "unverified", "log not readable (is debug on and the addon loaded?)" end
    if missingPosition(a, snapshots) then return "unverified", "log position missing (the step opened without it)" end
    if a.scope ~= "session" and snapshots and snapshots[a.source] and snapshots[a.source].unavailable then
        return "unverified", "log was not readable when the step opened"
    end
    local lines = a.scope == "session" and current or Evidence.NewLines(snapshots and snapshots[a.source], current, src.cap)
    if not lines then return "unverified", "log rolled over; evidence lost" end
    local want = 1
    for _, l in ipairs(lines) do
        if want <= #a.sequence and lineMatches(a.sequence[want], l) then want = want + 1 end
    end
    if want > #a.sequence then return "pass" end
    return "unverified", ("sequence stopped at item %d"):format(want)
end

-- A fact assertion. No fact is unverified, facts that break the operator fail. With count, the facts that pass
-- the operator are counted. The operator missing passes when no fact arrived.
function Evidence.CheckFact(a, snapshots, plan, env)
    local op = ops[a.op]
    if not op then return "unverified", "unknown op" end
    local lines, exact, src = window(a, snapshots, plan, env)
    if not lines then return "unverified", exact end
    local values = {}
    for _, l in ipairs(lines) do
        local addon, key, v = Evidence.ParseFact(l)
        if addon == a.addon and key == a.key then values[#values + 1] = v end
    end
    if a.count then
        local n = 0
        for _, v in ipairs(values) do if op(v, a.value, a) then n = n + 1 end end
        return judgeCount(n, a.count, lines, exact, src, a)
    end
    if a.op == "missing" then
        if #values > 0 then return "fail", "the fact arrived" end
        return judgeCount(0, { exactly = 0 }, lines, exact, src, a)
    end
    if #values == 0 then return "unverified", "no matching fact" end
    local which = a.which or "last"
    if which == "last" then return op(values[#values], a.value, a) and "pass" or "fail", nil end
    local any, all = false, true
    for _, v in ipairs(values) do
        if op(v, a.value, a) then any = true else all = false end
    end
    if which == "any" then return any and "pass" or "fail" end
    if all and a.scope ~= "session" and exact == false then return "unverified", "log rolled over; a fact that could contradict may be lost" end
    return all and "pass" or "fail"
end

function Evidence.CheckState(a, env)
    if not ns.Plan.PROBES[a.probe] then return "unverified", "unknown probe" end
    local op = ops[a.op]
    if not op then return "unverified", "unknown op" end
    local x = Evidence.Probe(a, env)
    if a.op == "missing" then -- a path that is not there, in a global that is
        local root = a.probe == "global-value" and a.path and (env or _G)[a.name]
        if type(root) ~= "table" then return "unverified", "value unavailable" end
    elseif x == nil and a.op ~= "exists" then return "unverified", "value unavailable" end
    return op(x, a.value, a) and "pass" or "fail"
end

function Evidence.Check(a, snapshots, plan, env)
    if a.kind == "log" then return Evidence.CheckLog(a, snapshots, plan, env) end
    if a.kind == "log-sequence" then return Evidence.CheckSequence(a, snapshots, plan, env) end
    if a.kind == "fact" then return Evidence.CheckFact(a, snapshots, plan, env) end
    return Evidence.CheckState(a, env)
end

-- Live view of the required checks of a step, without recording anything. Each item:
-- { label, state } where state is "met", "waiting", "bad" or "later" (an absence check is judged when the verdict is recorded).
function Evidence.Preview(step, snapshots, plan, env)
    local items = {}
    for _, a in ipairs(step.assertions or {}) do
        if not a.diagnostic then
            local item = { assertion = a, label = a.label }
            local upper = type(a.count) == "table" and (a.count.exactly ~= nil or a.count.max ~= nil)
            if a.absent or upper or (a.kind == "fact" and a.op == "missing") then
                -- Judged at the verdict, but a line that already broke it cannot be taken back: show that at once.
                item.state = Evidence.Check(a, snapshots, plan, env) == "fail" and "bad" or "later"
                item.timed = true -- an automatic step judges it when its timeout ends
            else
                local r = Evidence.Check(a, snapshots, plan, env)
                item.state = (r == "pass" and "met") or (r == "fail" and "bad") or "waiting"
            end
            items[#items + 1] = item
        end
    end
    return items
end

-- Where the logs a step checks stand when its attempt opens: { [source] = { n, tail } }. Only logs that an
-- attempt-scoped assertion of the step names are recorded. An unreadable log is not an empty one: marking it
-- keeps old lines from counting as new later.
function Evidence.Snapshot(plan, env, step)
    local snaps = {}
    for _, a in ipairs(step and step.assertions or {}) do
        local name = a.source
        if (a.kind == "log" or a.kind == "log-sequence" or a.kind == "fact") and a.scope ~= "session" and name and not snaps[name] then
            local src = plan.logs and plan.logs[name]
            local lines = src and Evidence.ReadLog(src, env)
            if lines then
                local tail = {}
                for i = math.max(1, #lines - Evidence.TAIL + 1), #lines do tail[#tail + 1] = lines[i] end
                snaps[name] = { n = #lines, tail = tail }
            else
                snaps[name] = { unavailable = true }
            end
        end
    end
    return snaps
end

