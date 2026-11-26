-- The harness's own assertions and runner behavior.
local ns, test, T, finish, H = dofile("tests/harness.lua")()

local function msg(fn, ...) local ok, err = pcall(fn, ...); assert(not ok, "expected a failure"); return tostring(err) end

-- Runs a Lua file under luajit in its own process; returns its output and exit code.
local function run(body, arg1)
    local path = os.tmpname()
    local f = assert(io.open(path, "w")); f:write(body); f:close()
    local p = io.popen("luajit " .. path .. (arg1 and (" '" .. arg1 .. "'") or "") .. " 2>&1; echo EXIT:$?")
    local out = p:read("*a"); p:close(); os.remove(path)
    return out, tonumber(out:match("EXIT:(%d+)%s*$"))
end
local PRE = 'local ns, test, T, finish, H = dofile("tests/harness.lua")()\n'

test("H.budgeted stops a runaway script, passes a normal one and puts the JIT and the hook back", function()
    local hookBefore = debug.gethook()
    local ok, v = H.budgeted(H.DEFAULT_BUDGET, function(a) return a + 1 end, 41)
    T.eq(ok, true); T.eq(v, 42)
    local bad, err = H.budgeted(H.DEFAULT_BUDGET, function() while true do end end)
    T.eq(bad, false); T.ok(tostring(err):find("script ran too long", 1, true), tostring(err))
    local reads, rerr = H.budgeted(H.DEFAULT_BUDGET, function() for i = 1, 50000 do math.floor(i) end end)
    T.eq(reads, false, "50,000 calls in one script is over the budget"); T.ok(rerr)
    T.eq(debug.gethook(), hookBefore, "no hook is left behind")
    if jit then T.eq(jit.status(), true, "the JIT is back on") end
end)

test("a budget can be small, and no budget is a plain pcall", function()
    T.eq((H.budgeted(100, function() for i = 1, 1000 do end end)), false)
    T.eq((H.budgeted(false, function() for i = 1, 3000000 do end return true end)), true)
    T.eq((H.budgeted(nil, function() return true end)), true)
end)

test("a timer callback that runs too long reports through advance, and later timers still run", function()
    local st = H.stubClient({ clock = {}, scriptBudget = H.DEFAULT_BUDGET })
    local ran = false
    C_Timer.After(1, function() while true do end end)
    C_Timer.After(2, function() ran = true end)
    local n, err = st.advance(5)
    T.eq(n, 2); T.ok(err and err:find("script ran too long", 1, true), tostring(err)); T.ok(ran)
    local st2 = H.stubClient({ clock = {} })
    C_Timer.After(1, function() for i = 1, 3000000 do end end)
    T.eq(select(2, st2.advance(2)), nil, "without a budget the same callback finishes")
end)

test("T.eq tells nil from the string nil, and 1 from the string 1", function()
    T.ok(msg(T.eq, nil, "nil"):find('expected "nil", got nil', 1, true))
    T.ok(msg(T.eq, "1", 1):find('expected number 1, got "1"', 1, true))
end)

test("T.same names the first differing path and both values", function()
    T.same({ a = { 1, 2 } }, { a = { 1, 2 } })
    local m = msg(T.same, { a = { b = { 1, 2, 3 } } }, { a = { b = { 1, 2, 4 } } }, "plan")
    T.ok(m:find("plan: differs at a.b.3: expected number 4, got number 3", 1, true), m)
    T.ok(msg(T.same, { x = 1 }, {}):find("differs at x: expected nil, got number 1", 1, true))
    T.ok(msg(T.same, 1, 2):find("differs at <root>", 1, true))
end)

test("T.deepEq still answers true or false", function()
    T.eq(T.deepEq({ 1, { 2 } }, { 1, { 2 } }), true)
    T.eq(T.deepEq({ 1 }, { 1, 2 }), false)
    T.eq(T.deepEq({ 1 }, "x"), false)
end)

test("T.raises fails when the call succeeds or the message differs, and shows the message", function()
    T.raises(function() error("boom now") end, "boom")
    T.raises(function() error("anything") end)
    T.ok(msg(T.raises, function() end, "boom"):find("the call succeeded", 1, true))
    local m = msg(T.raises, function() error("a typo: nil index") end, "protected")
    T.ok(m:find('expected an error containing "protected"', 1, true) and m:find("a typo: nil index", 1, true), m)
end)

test("H.stub and T.finally refuse to register outside a test", function()
    local out, code = run(PRE .. [[
local ok, err = pcall(H.stub, {}, "k", 1)
assert(not ok and tostring(err):find("outside a test", 1, true), tostring(err))
local ok2 = pcall(T.finally, function() end)
assert(not ok2)
test("a", function() end)
finish()]])
    T.eq(code, 0, out)
end)

test("a cleanup error is reported next to the test's own failure, and fails a passing test", function()
    local out, code = run(PRE .. [[
test("a", function() T.finally(function() error("restore broke") end); error("first") end)
test("b", function() T.finally(function() error("restore broke too") end) end)
finish()]])
    T.eq(code, 1); T.ok(out:find("first", 1, true) and out:find("cleanup failed: ", 1, true) and out:find("restore broke too", 1, true), out)
    T.ok(out:find("0 passed, 2 failed", 1, true), out)
end)

test("H.stub restores the old value, nil included, after a failed test", function()
    local out, code = run(PRE .. [[
local t = { keep = "old" }
test("a", function() H.stub(t, "keep", "new"); H.stub(t, "fresh", 1); error("boom") end)
test("b", function() T.eq(t.keep, "old"); T.eq(t.fresh, nil) end)
finish()]])
    T.eq(code, 1, "the failing test fails the file"); T.ok(out:find("FAIL a", 1, true) and not out:find("FAIL b", 1, true), out)
    T.ok(out:find("1 passed, 1 failed", 1, true), out)
end)

test("T.finally runs after the test, last registered first", function()
    local out, code = run(PRE .. [[
local order = {}
test("a", function() T.finally(function() order[#order + 1] = 1 end); T.finally(function() order[#order + 1] = 2 end) end)
test("b", function() T.eq(order[1], 2); T.eq(order[2], 1) end)
finish()]])
    T.eq(code, 0, out)
end)

test("a failing test prints a traceback without the harness's own frames", function()
    local out = run(PRE .. [[
local function deep() error("deep fail") end
test("a", function() deep() end)
finish()]])
    T.ok(out:find("FAIL a: ", 1, true) and out:find("stack traceback", 1, true), out)
    T.ok(out:find("'deep'", 1, true), "the helper frame shows: " .. out)
    T.ok(not out:find("tests/harness.lua", 1, true), out)
end)

test("a name filter that matches no test exits with the no-match code", function()
    local body = PRE .. 'test("alpha", function() end)\nfinish()'
    local _, none = run(body, "zzz")
    T.eq(none, H.NO_MATCH)
    local out, ok = run(body, "alp")
    T.eq(ok, 0, out)
    local _, plain = run(body)
    T.eq(plain, 0)
end)

test("run.lua passes the test name on, skips files with no match and fails when none match", function()
    local function runner(args)
        local p = io.popen("luajit tests/run.lua " .. args .. " 2>&1; echo EXIT:$?")
        local out = p:read("*a"); p:close()
        return out, tonumber(out:match("EXIT:(%d+)%s*$"))
    end
    local out, code = runner("test_harn 'T.same names the first'")
    T.eq(code, 0, out); T.ok(out:find("test_harness.lua", 1, true) and not out:find("test_plan.lua", 1, true), out)
    out, code = runner("test_harn 'no such test anywhere'")
    T.eq(code, 1, out); T.ok(out:find("no test matches", 1, true), out)
end)

finish()
