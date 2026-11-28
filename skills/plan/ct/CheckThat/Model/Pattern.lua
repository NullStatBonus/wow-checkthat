-- A Lua 5.1 pattern matcher in plain Lua (a port of lstrlib.c: str_find_aux and do_match), for the patterns of a plan.
-- The game cannot stop string.find once it runs long, and a plan's pattern may backtrack for minutes. This matcher counts
-- its steps and gives up at a budget, so a line that is too costly is reported as "could not be checked" instead of freezing the
-- client. It finds exactly what string.find finds. No game globals; Lua 5.1 syntax.
local _, ns = ...
local Pattern = {}
ns.Pattern = Pattern

-- A step is one call of the matcher for an item (doMatch), one test of a character against an item (singleMatch), or one item of a
-- set that is read (matchBracket), or one character of a %b scan. Measured in
-- LuaJIT with the JIT off (the nearest to the game's Lua here): 66 to 164 nanoseconds a step, so 40000 steps is 2 to 7 ms for one line.
Pattern.BUDGET = 40000

local byte, sub, error, pcall, type = string.byte, string.sub, error, pcall, type
local OVER = {} -- thrown when the budget is spent
local CAP_UNFINISHED, CAP_POSITION, MAXCAPTURES = -1, -2, 32

-- Character classes as the C locale knows them (what %a %c %d %l %p %s %u %w %x %z test), by byte.
local classTest = {
    [97] = function(c) return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) end,                                      -- a
    [99] = function(c) return c < 32 or c == 127 end,                                                                    -- c
    [100] = function(c) return c >= 48 and c <= 57 end,                                                                  -- d
    [108] = function(c) return c >= 97 and c <= 122 end,                                                                 -- l
    [112] = function(c) return (c >= 33 and c <= 47) or (c >= 58 and c <= 64) or (c >= 91 and c <= 96) or (c >= 123 and c <= 126) end, -- p
    [115] = function(c) return (c >= 9 and c <= 13) or c == 32 end,                                                      -- s
    [117] = function(c) return c >= 65 and c <= 90 end,                                                                  -- u
    [119] = function(c) return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) end,            -- w
    [120] = function(c) return (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102) end,            -- x
    [122] = function(c) return c == 0 end,                                                                               -- z
}

local function matchClass(c, cl)
    local upper = cl >= 65 and cl <= 90
    local test = classTest[upper and cl + 32 or cl]
    if not test then return cl == c end
    local res = test(c)
    if upper then return not res end
    return res
end

local function classEnd(ms, p)
    local pat, plen = ms.pat, ms.plen
    local c = byte(pat, p)
    p = p + 1
    if c == 37 then
        if p > plen then error("malformed pattern (ends with '%')", 0) end
        return p + 1
    elseif c == 91 then
        if byte(pat, p) == 94 then p = p + 1 end
        repeat
            if p > plen then error("malformed pattern (missing ']')", 0) end
            local cc = byte(pat, p)
            p = p + 1
            if cc == 37 and p <= plen then p = p + 1 end
        until byte(pat, p) == 93
        return p + 1
    end
    return p
end

-- p is the "[" of a set and ec its "]".
local function matchBracket(ms, c, p, ec)
    local pat = ms.pat
    local sig = true
    if byte(pat, p + 1) == 94 then sig = false; p = p + 1 end
    while true do
        p = p + 1
        if p >= ec then return not sig end
        local steps = ms.steps + 1 -- a step for each item of the set that is read
        ms.steps = steps
        if steps > ms.budget then error(OVER, 0) end
        if byte(pat, p) == 37 then
            p = p + 1
            if matchClass(c, byte(pat, p)) then return sig end
        elseif byte(pat, p + 1) == 45 and p + 2 < ec then
            p = p + 2
            if byte(pat, p - 2) <= c and c <= byte(pat, p) then return sig end
        elseif byte(pat, p) == c then return sig end
    end
end

local function singleMatch(ms, s, p, ep)
    local steps = ms.steps + 1
    ms.steps = steps
    if steps > ms.budget then error(OVER, 0) end
    if s > ms.slen then return false end
    local c = byte(ms.src, s)
    local pc = byte(ms.pat, p)
    if pc == 46 then return true
    elseif pc == 37 then return matchClass(c, byte(ms.pat, p + 1))
    elseif pc == 91 then return matchBracket(ms, c, p, ep - 1) end
    return pc == c
end

local doMatch

local function matchBalance(ms, s, p)
    if p >= ms.plen then error("unbalanced pattern", 0) end
    local src = ms.src
    if s > ms.slen or byte(src, s) ~= byte(ms.pat, p) then return nil end
    local b, e, cont = byte(ms.pat, p), byte(ms.pat, p + 1), 1
    s = s + 1
    while s <= ms.slen do
        local c = byte(src, s)
        ms.steps = ms.steps + 1
        if ms.steps > ms.budget then error(OVER, 0) end
        if c == e then
            cont = cont - 1
            if cont == 0 then return s + 1 end
        elseif c == b then cont = cont + 1 end
        s = s + 1
    end
    return nil
end

local function maxExpand(ms, s, p, ep)
    local i = 0
    while singleMatch(ms, s + i, p, ep) do i = i + 1 end
    while i >= 0 do
        local res = doMatch(ms, s + i, ep + 1)
        if res then return res end
        i = i - 1
    end
    return nil
end

local function minExpand(ms, s, p, ep)
    while true do
        local res = doMatch(ms, s, ep + 1)
        if res then return res end
        if singleMatch(ms, s, p, ep) then s = s + 1 else return nil end
    end
end

local function startCapture(ms, s, p, what)
    local level = ms.level + 1
    if level > MAXCAPTURES then error("too many captures", 0) end
    ms.capInit[level], ms.capLen[level] = s, what
    ms.level = level
    local res = doMatch(ms, s, p)
    if not res then ms.level = ms.level - 1 end
    return res
end

local function endCapture(ms, s, p)
    local l
    for i = ms.level, 1, -1 do
        if ms.capLen[i] == CAP_UNFINISHED then l = i; break end
    end
    if not l then error("invalid pattern capture", 0) end
    ms.capLen[l] = s - ms.capInit[l]
    local res = doMatch(ms, s, p)
    if not res then ms.capLen[l] = CAP_UNFINISHED end
    return res
end

local function matchCapture(ms, s, l)
    l = l - 48
    if l < 1 or l > ms.level or ms.capLen[l] == CAP_UNFINISHED then error("invalid capture index", 0) end
    local len = ms.capLen[l]
    if len < 0 or ms.slen - s + 1 < len then return nil end
    if sub(ms.src, ms.capInit[l], ms.capInit[l] + len - 1) == sub(ms.src, s, s + len - 1) then return s + len end
    return nil
end

-- Returns the index after the match of the pattern from item p at position s, or nil.
function doMatch(ms, s, p)
    local pat, plen = ms.pat, ms.plen
    while true do
        local steps = ms.steps + 1
        ms.steps = steps
        if steps > ms.budget then error(OVER, 0) end
        if p > plen then return s end
        local pc = byte(pat, p)
        local default = false
        if pc == 40 then
            if byte(pat, p + 1) == 41 then return startCapture(ms, s, p + 2, CAP_POSITION) end
            return startCapture(ms, s, p + 1, CAP_UNFINISHED)
        elseif pc == 41 then return endCapture(ms, s, p + 1)
        elseif pc == 36 and p == plen then
            if s == ms.slen + 1 then return s end
            return nil
        elseif pc == 37 then
            local nx = byte(pat, p + 1)
            if nx == 98 then
                s = matchBalance(ms, s, p + 2)
                if not s then return nil end
                p = p + 4
            elseif nx == 102 then
                p = p + 2
                if byte(pat, p) ~= 91 then error("missing '[' after '%f' in pattern", 0) end
                local ep = classEnd(ms, p)
                local prev = s == 1 and 0 or byte(ms.src, s - 1)
                local cur = s <= ms.slen and byte(ms.src, s) or 0
                if not matchBracket(ms, prev, p, ep - 1) and matchBracket(ms, cur, p, ep - 1) then p = ep else return nil end
            elseif nx and nx >= 48 and nx <= 57 then
                s = matchCapture(ms, s, nx)
                if not s then return nil end
                p = p + 2
            else default = true end
        else default = true end
        if default then
            local ep = classEnd(ms, p)
            local epc = byte(pat, ep)
            if epc == 63 then
                if singleMatch(ms, s, p, ep) then
                    local res = doMatch(ms, s + 1, ep + 1)
                    if res then return res end
                end
                p = ep + 1
            elseif epc == 42 then return maxExpand(ms, s, p, ep)
            elseif epc == 43 then
                if singleMatch(ms, s, p, ep) then return maxExpand(ms, s + 1, p, ep) end
                return nil
            elseif epc == 45 then return minExpand(ms, s, p, ep)
            else
                if not singleMatch(ms, s, p, ep) then return nil end
                s = s + 1
                p = ep
            end
        end
    end
end

-- The port. Returns true, then where (start and end, as string.find), or false, or nil when the budget was spent; and the steps used.
-- startOnly tries position 1 only (see strip below). Raises for a pattern string.find would raise on: check Plan.PatternProblem first.
local function run(src, pat, budget, startOnly)
    local anchor = byte(pat, 1) == 94
    local ms = { src = src, slen = #src, pat = pat, plen = #pat, steps = 0, budget = budget or Pattern.BUDGET,
        level = 0, capInit = {}, capLen = {} }
    local ok, found, first, last = pcall(function()
        local s1 = 1
        while true do
            ms.level = 0
            local e = doMatch(ms, s1, anchor and 2 or 1)
            if e then
                for i = 1, ms.level do -- string.find hands the captures back, and raises for one that is not closed
                    if ms.capLen[i] == CAP_UNFINISHED then error("unfinished capture", 0) end
                end
                return true, s1, e - 1
            end
            if anchor or startOnly or s1 > ms.slen then return false end
            s1 = s1 + 1
        end
    end)
    if ok then return found, first, last, ms.steps end
    if found == OVER then return nil, nil, nil, ms.steps end
    error(found, 0)
end

local SPECIAL = "[%^%$%*%+%?%.%(%[%%%-]"
function Pattern.Match(src, pat, budget)
    if not pat:find(SPECIAL) then -- as string.find: no special character is a plain search
        local first, last = string.find(src, pat, 1, true)
        return first ~= nil, first, last
    end
    local found, first, last = run(src, pat, budget)
    return found, first, last
end

-- ---------------------------------------------------------------------------------------------------------------------------
-- The hybrid. The C matcher is about 40 times faster than the port, and for a pattern with at most one unbounded repeat its cost
-- is bounded by the line and the pattern, so a "simple" pattern on a short line runs string.find. Everything else runs the port.
Pattern.NATIVE_LINE = 2000    -- longest line a simple pattern runs natively
Pattern.NATIVE_WORK = 4000000 -- most estimated work a native call may be worth. A unit is 0.4 to 1.1 nanoseconds measured: at most about 4.5 ms
Pattern.NATIVE_UNIT = 100     -- native work units that cost as much as one port step (about 1 ns against about 100 ns)

local function setEnd(p, i) -- the index after the "]" of the set that starts at i, or nil
    local n = #p
    i = i + 1
    if byte(p, i) == 94 then i = i + 1 end
    repeat
        if i > n then return nil end
        local ch = byte(p, i)
        i = i + 1
        if ch == 37 and i <= n then i = i + 1 end
    until byte(p, i) == 93
    return i + 1
end

-- What the pattern is made of: repeats (* + -), qmarks (?), items, a back reference, and whether it starts with .* or .- (strip).
local function scan(pat)
    local info = { repeats = 0, qmarks = 0, items = 0, backref = false, anchored = false, strip = false, first = false }
    local n, i = #pat, 1
    if byte(pat, 1) == 94 then info.anchored = true; i = 2 end
    if not info.anchored then
        -- string.find(s, p) is string.find(s, "^" .. p) when p starts with .* or .-, also inside plain "(": a match from a later start
        -- is also one from the first, as the leading repeat takes the text before it. A back reference could see that text.
        local j = i
        while byte(pat, j) == 40 and byte(pat, j + 1) ~= 41 do j = j + 1 end
        if byte(pat, j) == 46 and (byte(pat, j + 1) == 42 or byte(pat, j + 1) == 45) then info.strip = true; i = j + 2 end
    end
    local seen = false
    local function single(first, last, literal)
        info.items = info.items + 1
        local q = byte(pat, last + 1)
        if q == 42 or q == 43 or q == 45 then info.repeats = info.repeats + 1; last = last + 1
        elseif q == 63 then info.qmarks = info.qmarks + 1; last = last + 1 end
        if not seen and not info.strip then
            seen = true
            if literal and q ~= 42 and q ~= 45 and q ~= 63 then info.first = literal end
        end
        return last + 1
    end
    while i <= n do
        local ch = byte(pat, i)
        if ch == 40 or ch == 41 then i = i + 1
        elseif ch == 36 and i == n then i = i + 1
        elseif ch == 37 then
            local d = byte(pat, i + 1)
            if d == 98 then info.items = info.items + 1; i = i + 4
            elseif d == 102 then
                local e = setEnd(pat, i + 2)
                info.items = info.items + 1
                i = e or n + 1
            elseif d and d >= 48 and d <= 57 then info.backref = true; i = i + 2
            else i = single(i, i + 1, d and not (d >= 48 and d <= 57) and not classTest[d] and not (d >= 65 and d <= 90) and d or nil) end
        elseif ch == 91 then
            local e = setEnd(pat, i)
            i = single(i, (e or n + 1) - 1, nil)
        elseif ch == 46 then i = single(i, i, nil)
        else i = single(i, i, ch) end
    end
    if info.backref then info.strip = false end
    info.plain = not pat:find(SPECIAL)
    return info
end

local infos, infoCount = {}, 0
local function infoOf(pat)
    local info = infos[pat]
    if not info then
        local ok, got = pcall(scan, pat)
        info = ok and got or { backref = true, repeats = 9, qmarks = 9, items = #pat, strip = false, anchored = false, first = false, plain = false }
        if infoCount >= 500 then infos, infoCount = {}, 0 end
        infos[pat] = info
        infoCount = infoCount + 1
    end
    return info
end
Pattern.Info = infoOf

local function countChar(src, ch, n)
    local count, pos, c = 0, 1, string.char(ch)
    while true do
        pos = string.find(src, c, pos, true)
        if not pos then return count end
        count = count + 1
        pos = pos + 1
    end
end

-- Estimated work of string.find on this line, in native units: the start positions times the repeat's reach times the items after it,
-- doubled for each "?". An upper bound: measured 0.4 ns a unit for a?a?a?a.-Z and 1.1 ns for .- before a 190-character tail.
local function nativeWork(info, src, n)
    local starts = 1
    if not info.anchored and not info.strip then
        starts = info.first and countChar(src, info.first, n) or n
        if starts < 1 then starts = 1 end
    end
    local reach = info.repeats > 0 and n or 1
    -- A stripped leading repeat is still a repeat for string.find: it takes every length, and the rest of the pattern runs after each.
    if info.strip then reach = reach * n end
    return starts * reach * (info.items + 1) * 2 ^ info.qmarks
end

-- Does pattern match in src? Returns true or false and the engine ("plain", "native" or "port") and its cost in port steps; or nil,
-- "over" when the port spent its budget (the line could not be checked) and the steps spent.
function Pattern.Search(src, pat)
    local info = infoOf(pat)
    local n = #src
    if info.plain then
        return string.find(src, pat, 1, true) ~= nil, "plain", 4 + n / 16
    end
    if not info.backref and info.repeats <= 1 and info.qmarks <= 3 and n <= Pattern.NATIVE_LINE then
        local work = nativeWork(info, src, n)
        if work <= Pattern.NATIVE_WORK then
            local ok, r = pcall(string.find, src, info.strip and "^" .. pat or pat)
            if ok then return r ~= nil, "native", 4 + work / Pattern.NATIVE_UNIT + n / 16 end
        end
    end
    local found, _, _, steps = run(src, pat, Pattern.BUDGET, info.strip)
    if found == nil then return nil, "over", steps end
    return found, "port", steps
end

-- ---------------------------------------------------------------------------------------------------------------------------
-- A pass is one evaluation of the checks for the card: a refresh (Evidence.Preview). Judging a result (Evidence.Check) is not one. It may spend
-- PASS_ALLOWANCE port steps (a native call is charged what it is worth in steps). When that is spent, a line not seen before is
-- "pending": it is not run and not kept, and the next pass goes on from the lines already kept. About 20 ms at 110 ns a step.
Pattern.PASS_ALLOWANCE = 150000
local spent, depth, unmetered = 0, 0, 0

function Pattern.Pass(fn, ...)
    if depth == 0 then
        spent = 0
        if Pattern.curCount >= Pattern.CACHE_MAX then Pattern.Rotate() end
    end
    depth = depth + 1
    local ok, a, b, c = pcall(fn, ...)
    depth = depth - 1
    if not ok then error(a, 0) end
    return a, b, c
end
-- Runs fn with no allowance: whatever records a result must judge every line (the budget for one line still applies), as a
-- result is written once and never retried. "pending" is only ever seen by the live card.
function Pattern.Unmetered(fn, ...)
    unmetered = unmetered + 1
    local ok, a, b, c = pcall(fn, ...)
    unmetered = unmetered - 1
    if not ok then error(a, 0) end
    return a, b, c
end
function Pattern.Spent() return spent end

-- The answer for a pattern and a line is kept, "could not be checked" too, so the next refresh does not repeat the work. Two
-- generations: a hit in the old one moves to the new one; when the new one holds CACHE_MAX pairs at the start of a pass it becomes
-- the old one and the old one is dropped. { [pattern] = { [line] = true | false | "over" } }
Pattern.CACHE_MAX = 20000
local cur, prev = {}, {}
Pattern.curCount, Pattern.prevCount = 0, 0
function Pattern.Rotate()
    prev, cur = cur, {}
    Pattern.prevCount, Pattern.curCount = Pattern.curCount, 0
end
local function keep(pat, src, value)
    local t = cur[pat]
    if not t then t = {}; cur[pat] = t end
    if t[src] == nil then Pattern.curCount = Pattern.curCount + 1 end
    t[src] = value
end

-- Returns true or false; or nil and why: "over" (the line took too long) or "pending" (this pass has no allowance left).
function Pattern.Find(src, pat)
    local t = cur[pat]
    local hit = t and t[src]
    if hit == nil then
        local o = prev[pat]
        hit = o and o[src]
        if hit ~= nil then keep(pat, src, hit) end
    end
    if hit ~= nil then
        if hit == "over" then return nil, "over" end
        return hit
    end
    if depth > 0 and unmetered == 0 and spent >= Pattern.PASS_ALLOWANCE then return nil, "pending" end
    local found, engine, cost = Pattern.Search(src, pat)
    spent = spent + cost
    keep(pat, src, found == nil and "over" or found)
    if found == nil then return nil, "over" end
    return found
end
function Pattern.CacheSize() return Pattern.curCount + Pattern.prevCount end
function Pattern.ClearCache() cur, prev = {}, {}; Pattern.curCount, Pattern.prevCount = 0, 0; spent = 0 end
