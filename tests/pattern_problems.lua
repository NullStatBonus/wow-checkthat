-- Prints Plan.PatternProblem for each pattern of a JSON list (one line each, "nil" when there is none). tools/test_ct.py compares it with
-- tools/ct.py pattern_problem on a generated set.
--   luajit tests/pattern_problems.lua patterns.json
local ns = {}
assert(loadfile("CheckThat/Model/Json.lua"))("CheckThat", ns)
assert(loadfile("CheckThat/Model/Plan.lua"))("CheckThat", ns)
local f = assert(io.open(arg[1], "rb"))
local list = assert(ns.Json.Decode(f:read("*a")))
f:close()
for _, p in ipairs(list) do print(tostring(ns.Plan.PatternProblem(p))) end
