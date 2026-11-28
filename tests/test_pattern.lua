local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local P = ns.Pattern
local BIG = 1e8

local function native(s, p)
    local ok, a, b = pcall(string.find, s, p)
    return ok, a, b
end
-- Pattern.Match (the port) must do what string.find does: raise when it raises, else find the same place.
local cases = 0
local function same(p, s)
    cases = cases + 1
    local okN, a, b = native(s, p)
    local okP, found, c, d = pcall(P.Match, s, p, BIG)
    T.eq(okP, okN, ("raising on %q in %q"):format(p, s))
    if okN then
        T.eq(found, a ~= nil, ("found %q in %q"):format(p, s))
        if a then T.eq(c, a, ("start of %q in %q"):format(p, s)); T.eq(d, b, ("end of %q in %q"):format(p, s)) end
    end
    return okN
end

local seed = 20260301
local function rnd(n) seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n + 1 end
local ATOMS = { "a", "b", "x", " ", ".", "%d", "%a", "%s", "%w", "%p", "%u", "%l", "%x", "%c", "%z", "%D", "%S", "%W", "%.", "%%", "%q", "[abc]", "[^abc]",
    "[a-c]", "[%d_]", "[]]", "[^]]", "[%a-]", "(", ")", "()", "%1", "%2", "%b()", "%bxy", "%f[%w]", "%f[%W]", "^", "$", "*", "+", "-", "?", "1", "(a)", "(%w+)", "[", "]", "%" }
local function pattern()
    local t = {}
    for i = 1, rnd(7) do t[i] = ATOMS[rnd(#ATOMS)] end
    return table.concat(t)
end
local ALPHA = { "a", "b", "x", " ", "1", "2", ".", "%", "(", ")", "[", "]", "A", "_", "-", "y" }
local function subject()
    local t = {}
    for i = 1, rnd(13) - 1 do t[i] = ALPHA[rnd(#ALPHA)] end
    return table.concat(t)
end
local FIXED = { "", "a", "ab", "abc 123", "foo bar", "[x] y", "(a(b)c)", "aa", "hello world", "  trim me  ", "a.b", "]]", "12.5 ms", "x=1, y=2", "%d", "ERROR boom" }

test("the matcher finds what string.find finds: generated patterns and subjects, errors included", function()
    local valid, raised = 0, 0
    for _ = 1, 1500 do
        local p = pattern()
        local anyRaise = false
        for _, s in ipairs(FIXED) do if not same(p, s) then anyRaise = true end end
        for _ = 1, 6 do if not same(p, subject()) then anyRaise = true end end
        if ns.Plan.PatternProblem(p) == nil then
            valid = valid + 1
            T.ok(not anyRaise, "the validator passed a pattern string.find raises on: " .. p)
        else raised = raised + 1 end
    end
    T.ok(valid > 200 and raised > 200, "both kinds were generated: " .. valid .. " valid, " .. raised .. " refused")
    T.ok(cases > 30000, "cases: " .. cases)
end)

local function readJson(path) local f = assert(io.open(path, "rb")); local s = f:read("*a"); f:close(); return assert(ns.Json.Decode(s)) end

test("the matcher agrees with string.find on the shared pattern set, on subjects built from each pattern", function()
    local n = 0
    for _, c in ipairs(readJson("tests/fixtures/parity-patterns.json")) do
        local p = c.pattern
        if not p:find("\0", 1, true) then -- Lua 5.1 ends a pattern at a NUL: the validators refuse it
            local plain = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "")
            local raised = false
            for _, s in ipairs({ unpack(FIXED), plain, plain .. plain, "x" .. plain, string.rep("a", 30), string.rep("(", 30) }) do
                if not same(p, s) then raised = true end
            end
            n = n + 1
            if c.problem and not p:find("^a+$") and #p <= 200 and not p:find("^%(%)") then
                T.ok(raised, "string.find does not raise on a pattern the validator refuses: " .. p)
            elseif not c.problem then T.ok(not raised, "string.find raises on a pattern the validator accepts: " .. p) end
        end
    end
    T.ok(n >= 90)
end)

-- The hybrid: Search must say what string.find says, whichever engine it picks, and a leading .* or .- may be dropped.
local PREFIX = { "", "", "", ".*", ".-", "(.*)", "(.-)", "((.-)", "^", ".*(", ".-." }
test("the hybrid finds what string.find finds, with the leading .* and .- stripped and every engine in use", function()
    local engines, strips, total = { plain = 0, native = 0, port = 0 }, 0, 0
    for _ = 1, 2500 do
        local p = PREFIX[rnd(#PREFIX)] .. pattern()
        if ns.Plan.PatternProblem(p) == nil then
            for _, s in ipairs(FIXED) do
                local found, engine = P.Search(s, p)
                T.ok(found ~= nil, "no budget is hit on a short line: " .. p)
                T.eq(found, string.find(s, p) ~= nil, ("%q in %q by %s"):format(p, s, engine))
                engines[engine] = engines[engine] + 1; total = total + 1
            end
            for _ = 1, 4 do
                local s = subject()
                T.eq((P.Search(s, p)), string.find(s, p) ~= nil, ("%q in %q"):format(p, s))
                total = total + 1
            end
            if P.Info(p).strip then strips = strips + 1 end
        end
    end
    T.ok(engines.plain > 100 and engines.native > 500 and engines.port > 500, "engines: " .. engines.plain .. " " .. engines.native .. " " .. engines.port)
    T.ok(strips > 100, "stripped patterns: " .. strips)
    T.ok(total > 20000, "hybrid cases: " .. total)
end)
test("a pattern that starts with .* or .- finds the same place as the same pattern anchored, captures included", function()
    local n = 0
    for _ = 1, 3000 do
        local body = pattern()
        for _, head in ipairs({ ".*", ".-", "(.*)", "(.-)" }) do
            local p = head .. body
            if ns.Plan.PatternProblem(p) == nil and not P.Info(p).backref then
                for _, s in ipairs(FIXED) do
                    local ok1, a1, b1, c1, d1 = pcall(string.find, s, p)
                    local ok2, a2, b2, c2, d2 = pcall(string.find, s, "^" .. p)
                    T.eq(ok1, ok2, p); n = n + 1
                    if ok1 then T.eq(a1, a2, p .. " in " .. s); T.eq(b1, b2); T.eq(c1, c2); T.eq(d1, d2) end
                end
            end
        end
    end
    T.ok(n > 10000, "cases: " .. n)
    T.eq(P.Info("(.*)x%1").strip, false, "a back reference could see the text the leading repeat takes")
    T.eq(P.Info("^.*x").strip, false, "an anchored pattern has nothing to strip")
end)
test("the engine for a pattern: plain, native for a simple one on a short line, the port for the rest", function()
    local function engine(p, s) local _, e = P.Search(s, p); return e end
    local short = string.rep("the quick brown fox ", 10)
    T.eq(engine("failed", short), "plain")
    T.eq(engine(".*failed", short), "native"); T.eq(engine("(.*)failed", short), "native"); T.eq(engine(".*error.*", short), "native")
    T.eq(engine("^%s*(.-)%s*$", short), "port", "two repeats")
    T.eq(engine("%w+%s*=%s*%d+", short), "port")
    T.eq(engine("(a)%1", short), "port", "a back reference")
    T.eq(engine("a?b?c?d?e", short), "port", "four question marks")
    T.eq(engine("a?b?c?de", short), "native", "three question marks")
    T.eq(engine(".*failed", string.rep("x", 2001)), "port", "a line over 2000 characters, but the leading repeat is dropped, so the port finishes")
    T.ok(P.Search(string.rep("x", 5000), ".*failed") == false, "and it is not left unchecked")
    T.eq(engine("e.*z", string.rep("x", 2001)), "port", "a simple pattern on a line over 2000 characters")
    T.eq(engine("e.*z", string.rep("e", 2001)), "over", "and the port gives up on the worst line")
    T.eq(engine("a.-b", string.rep("a", 2000)), "over", "the work estimate is over the limit: the port runs it and gives up")
    T.eq(engine("a.-b", string.rep("a", 300)), "native", "under the limit it is native")
    T.eq(engine("e.*z", short), "native")
end)
test("ordinary patterns of old plans are never left unchecked on ordinary lines up to 2000 characters, and agree with string.find", function()
    local words = "the quick brown fox [kt] merchant started: bag 12 of 30 free slots, vendor=Bob level=5 error: failed to open file, x = 42 "
    local pats = { ".*failed", ".-failed", ".*error.*", "(.*)failed", ".*%d+", "%w+%s*=%s*%d+", "%d+%.?%d*", "(%S+)%s+(.+)", ": *.*", "%[(.-)%]%s*(.*)",
        "%a+%s*%a*", "^%s*(.-)%s*$", "(%d+) (%d+) (%d+) (%d+) (%d+)", "%d+:%d+:%d+%.%d+ %a+", "error.*", "failed", "x = %d+", "slots, vendor=(%a+)" }
    for _, n in ipairs({ 60, 150, 300, 600, 1000, 2000 }) do
        local line = string.rep(words, math.ceil(n / #words)):sub(1, n)
        for _, p in ipairs(pats) do
            local found = P.Search(line, p)
            T.ok(found ~= nil, p .. " is left unchecked on " .. n .. " characters")
            T.eq(found, string.find(line, p) ~= nil, p .. " on " .. n)
        end
    end
end)
test("every pattern in the repository's plans is run as string.find would, on ordinary lines up to 2000 characters", function()
    local lines = { "[ct] report requested: Stored: 12 runs (limit 20), 3 plan copies", "items: spend of 12 pending", "confirm: bought Linen Cloth anyway",
        "[skills] collapsed headers: 3", "[professionjournal] on: 4 materials listed", "plan ClosestVendor digest 1a2b3c", "[ct] run started ClosestVendor-1" }
    local noise = string.rep("the quick brown fox [kt] merchant started: bag 12 of 30 free slots, vendor=Bob level=5 ", 30)
    local list, seen = io.popen("ls build/*.ct 2>/dev/null"), {}
    local function scan(v)
        if type(v) ~= "table" then return end
        if v.kind == "log" or v.kind == "log-sequence" or v.kind == "fact" or v.kind == "state" then
            for _, m in ipairs(v.sequence or { v }) do
                local pat = m.pattern or (v.op == "matches" and v.value) or nil
                if pat then seen[pat] = true end
            end
        end
        for _, c in pairs(v) do scan(c) end
    end
    for path in list:lines() do local f = assert(io.open(path)); local s = f:read("*a"); f:close(); scan(assert(ns.Codec.Decode(s))) end
    list:close()
    local n = 0
    for pat in pairs(seen) do
        n = n + 1
        for _, s in ipairs(lines) do T.eq((P.Search(s, pat)), string.find(s, pat) ~= nil, pat) end
        for _, len in ipairs({ 80, 300, 600, 1000, 2000 }) do
            local found = P.Search(noise:sub(1, len), pat)
            T.ok(found ~= nil, pat .. " is left unchecked on " .. len .. " characters")
            T.eq(found, string.find(noise:sub(1, len), pat) ~= nil, pat)
        end
    end
    T.ok(n >= 5, "plans hold patterns: " .. n)
end)

test("the budget stops a match that would take long, and the answer is nil, quickly", function()
    local started = os.clock()
    local flood = string.rep("a", 1000)
    local set88 = "[^" .. ("bcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-.,;:!"):sub(1, 70) .. "]"
    local cases = {
        { ".-.-.-.-Z", flood }, { "a.-a.-a.-a.-Z", flood }, { ".-.-.-Z", flood },
        { string.rep("%d?", 20) .. " ms", string.rep("1", 51) }, { string.rep("a?", 26) .. "b", string.rep("a", 60) },
        { ".-" .. string.rep("a?", 12) .. "b", flood },
        { set88 .. "*" .. set88 .. "*x", string.rep("a", 300) }, { set88 .. "*" .. set88 .. "*x", string.rep("a", 120) },
        { "%w+%s*=%s*%d+", string.rep("a", 400) }, { "(%S+)%s+(.+)", string.rep("a", 400) },
    }
    for _, c in ipairs(cases) do
        local t0 = os.clock()
        T.eq(P.Match(c[2], c[1]), nil, c[1]:sub(1, 30) .. " on " .. #c[2] .. " characters is over the budget")
        T.eq((P.Search(c[2], c[1])), nil, c[1]:sub(1, 30) .. " by the hybrid")
        T.ok(os.clock() - t0 < 0.5, c[1]:sub(1, 30) .. " took " .. (os.clock() - t0) .. " s")
    end
    T.ok(os.clock() - started < 2, "all together: " .. (os.clock() - started) .. " s")
    T.eq(P.Match(flood, "a.-a.-Z", 100), nil, "a budget argument is honoured")
    T.eq(P.Match("abc", "b", 100), true); T.eq(P.Match("abc", "z"), false)
    local found, s, e = P.Match("xx[ab]yy", "%[(.-)%]"); T.eq(found, true); T.eq(s, 3); T.eq(e, 6)
end)
test("a set is charged a step for each item it reads, so two big sets stop at the budget", function()
    local function steps(p, s) local lo, hi = 1, 1e9; while lo < hi do local mid = math.floor((lo + hi) / 2); if P.Match(s, p, mid) ~= nil then hi = mid else lo = mid + 1 end end return lo end
    local one = "[^abc]"
    local big = "[^" .. ("bcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-.,;:!"):sub(1, 60) .. "]"
    local s = string.rep("a", 30)
    T.ok(steps(big .. "*x", s) > 50 * steps(one .. "*x", s), "a set of 60 items costs far more than a set of 3: " .. steps(big .. "*x", s) .. " against " .. steps(one .. "*x", s))
    -- what the charge is for: the time. Two sets of 70 items on 120 characters took 70 ms when a set cost one step.
    local set70 = "[^" .. ("bcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_-.,;:!"):sub(1, 70) .. "]"
    for _, n in ipairs({ 120, 300 }) do
        local t0 = os.clock()
        T.eq(P.Match(string.rep("a", n), set70 .. "*" .. set70 .. "*x"), nil, "over the budget on " .. n)
        T.ok(os.clock() - t0 < 0.025, "it took " .. (os.clock() - t0) .. " s on " .. n .. " characters")
    end
end)

test("a pass lets a refresh spend an allowance: lines not seen before are pending, and the next pass goes on from the kept ones", function()
    P.ClearCache()
    local real = P.Search
    local calls = 0
    H.stub(P, "Search", function(...) calls = calls + 1; return real(...) end)
    local keep = P.PASS_ALLOWANCE
    P.PASS_ALLOWANCE = 2000 -- about 100 short lines
    local lines = {}
    for i = 1, 300 do lines[i] = "line number " .. i .. " of the log" end
    local function pass()
        return P.Pass(function()
            local found, pending = 0, 0
            for _, l in ipairs(lines) do
                local f, why = P.Find(l, "n.-r %d+")
                if f then found = found + 1 elseif f == nil and why == "pending" then pending = pending + 1 end
            end
            return found, pending
        end)
    end
    local found1, pending1 = pass()
    T.ok(pending1 > 0 and pending1 < 300 and found1 + pending1 <= 300, "the first pass was cut short: " .. found1 .. " found, " .. pending1 .. " pending")
    local after1 = calls
    T.ok(after1 < 300, "not every line was run: " .. after1)
    local passes, found, pending = 1, found1, pending1
    while pending > 0 and passes < 20 do passes = passes + 1; found, pending = pass() end
    T.eq(pending, 0); T.eq(found, 300, "every line matches in the end"); T.ok(passes >= 3, "it took " .. passes .. " passes")
    T.eq(calls, 300, "each line was run once: the kept answers cost nothing")
    local before = calls
    pass(); T.eq(calls, before, "a further pass runs nothing")
    P.PASS_ALLOWANCE = keep
    T.ok(not P.Pass or P.Spent() >= 0)
end)

test("Find keeps its answer, also 'could not be checked', and a hit in the old generation moves to the new one", function()
    P.ClearCache()
    local calls = 0
    local real = P.Search
    H.stub(P, "Search", function(...) calls = calls + 1; return real(...) end)
    local flood = string.rep("a", 1000)
    T.eq(P.Find("hello world", "o w"), true); T.eq(P.Find("hello world", "o w"), true); T.eq(calls, 1, "a found line is asked once")
    T.eq(P.Find("hello", "z"), false); T.eq(P.Find("hello", "z"), false); T.eq(calls, 2, "a miss is kept too")
    T.eq((P.Find(flood, ".-.-.-.-Z")), nil); T.eq((P.Find(flood, ".-.-.-.-Z")), nil); T.eq(calls, 3, "a line that took too long is kept too")
    T.eq(select(2, P.Find(flood, ".-.-.-.-Z")), "over")
    T.eq(P.CacheSize(), 3)
    P.Rotate()
    T.eq(P.CacheSize(), 3, "rotating keeps the old generation")
    T.eq(P.Find("hello", "z"), false); T.eq(calls, 3, "an old answer is found and moved to the new generation")
    P.Rotate()
    T.eq(P.Find("hello", "z"), false); T.eq(calls, 3, "and it was kept there: one rotation later it is still known")
    P.Rotate(); P.Rotate()
    T.eq(P.CacheSize(), 0, "an answer not used for two rotations is dropped")
    T.eq(P.Find("hello", "z"), false); T.eq(calls, 4)
    P.ClearCache(); T.eq(P.CacheSize(), 0)
end)
test("the cache holds more than 4000 pairs, so a large window is not run again at each refresh", function()
    P.ClearCache()
    local calls = 0
    local real = P.Search
    H.stub(P, "Search", function(...) calls = calls + 1; return real(...) end)
    local lines = {}
    for i = 1, 6000 do lines[i] = "[kt] entry " .. i .. " ok" end
    local function pass() return P.Pass(function() local n = 0; for _, l in ipairs(lines) do local f = P.Find(l, "y %d+ o") ; if f then n = n + 1 end end; return n end) end
    T.eq(pass(), 6000); T.eq(calls, 6000)
    T.eq(pass(), 6000); T.eq(calls, 6000, "the second refresh runs nothing")
    T.eq(pass(), 6000); T.eq(calls, 6000)
    T.ok(P.CacheSize() >= 6000 and P.CACHE_MAX >= 20000, "a generation holds 20000 pairs")
    P.ClearCache()
end)
test("an invalid pattern raises, as string.find does: the validator refuses it before it is run", function()
    for _, p in ipairs({ "(", "%", "[a", "%b", "(a)%2", "%f" }) do
        T.ok(not pcall(P.Match, "a(b%[", p), p)
        T.ok(ns.Plan.PatternProblem(p), p)
    end
    T.ok(ns.Plan.PatternProblem("a" .. string.char(0) .. "b"):find("NUL byte; write %z", 1, true), "a NUL byte is refused")
end)
-- What the hybrid promises for the native path: string.find costs no more than its charge says. Timed against the charge (one step
-- is about 0.1 microsecond; allow twice that) over a generated set, including stripped patterns with ? and a second repeat.
test("a native call costs no more than the steps it is charged, and the worst native call is a few milliseconds", function()
    local function bigText(n) return string.rep("the quick brown fox [kt] merchant started: bag 12 of 30 free slots ", math.ceil(n / 65)):sub(1, n) end
    local A = { "a", "a?", "a", ".", ".*", ".-", "Z", "%d", "x", "a*", "(", ")", "b?", "[ab]", "a+" }
    local PRE = { "", "", ".*", ".-", "(.*)", ".*a?a?", ".-a?" }
    local worst, nativeCalls, ratioChecked = 0, 0, 0
    -- A native call is timed three times and judged on the fastest: one sample also holds scheduler noise, which failed
    -- about one run in eight on a loaded machine (#275). The step charge is the same each time.
    local function measure(p, s)
        local ms, engine, cost = math.huge
        for _ = 1, 3 do
            local t0 = os.clock()
            local _, e, c = P.Search(s, p)
            ms, engine, cost = math.min(ms, (os.clock() - t0) * 1000), e, c
            if engine ~= "native" then break end
        end
        if engine == "native" then
            nativeCalls = nativeCalls + 1
            if ms > worst then worst = ms end
            T.ok(ms < 8, ("%q on %d characters took %.2f ms natively"):format(p, #s, ms))
            if cost > 2000 then
                ratioChecked = ratioChecked + 1
                T.ok(ms <= cost * 0.0002 + 0.3, ("%q on %d characters: %.2f ms for a charge of %d steps"):format(p, #s, ms, cost))
            end
        end
    end
    for _, c in ipairs({ { ".*a?a?a?a.*Z", 2000 }, { ".*a.*Z", 2000 }, { ".-a?a?a?a.-Z", 2000 }, { "a?a?a?a.-Z", 1000 }, { ".*a?a?a?a.*Z", 600 },
        { "(.*)a?a?a?a.*Z", 1500 }, { "a.-b", 1000 }, { ".*a?a?a?a", 2000 } }) do
        measure(c[1], string.rep("a", c[2]))
    end
    T.ok(select(2, P.Search(string.rep("a", 2000), ".*a?a?a?a.*Z")) ~= "native", "the stripped repeat counts: this one goes to the port")
    T.ok(select(2, P.Search(string.rep("a", 2000), ".*a.*Z")) ~= "native")
    for _ = 1, 1200 do
        local t = {}
        for i = 1, rnd(5) do t[i] = A[rnd(#A)] end
        local p = PRE[rnd(#PRE)] .. table.concat(t)
        if ns.Plan.PatternProblem(p) == nil then
            for _, n in ipairs({ 200, 800, 2000 }) do
                measure(p, string.rep("a", n)); measure(p, bigText(n))
            end
        end
    end
    T.ok(nativeCalls > 1500 and ratioChecked > 20, "native calls timed: " .. nativeCalls .. ", against their charge: " .. ratioChecked)
end)
test("the cache size is set once", function()
    local f = assert(io.open("CheckThat/Model/Pattern.lua")); local s = f:read("*a"); f:close()
    local n = 0
    for _ in s:gmatch("\nPattern%.CACHE_MAX = ") do n = n + 1 end
    T.eq(n, 1, "one CACHE_MAX assignment")
end)
print(cases .. " differential cases")
finish()
