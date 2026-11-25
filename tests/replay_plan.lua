-- Usage (from the project root): luajit tests/replay_plan.lua build/<plan>.ct [hooks.lua|-] [interface number]
-- The interface number picks the client: 16000 or more is forever-camelot (the default), below it classic-era.
-- Plays a compiled plan in the fake client and prints each step's result, the steps the card shows twice and every
-- problem. Exits 1 when there is a problem. See tests/replay.lua for the hooks file.
local ns, _, _, _, H = dofile("tests/harness.lua")()
H.stubClient({ toc = 16000 })
H.plain(ns)
local f = assert(io.open(arg[1], "rb")); local planString = f:read("*a"); f:close()
local hooks = arg[2] and arg[2] ~= "-" and dofile(arg[2]) or {}
local out = dofile("tests/replay.lua").run(ns, planString, { hooks = hooks, interface = tonumber(arg[3]) })
for _, line in ipairs(out.trace) do io.write(line, "\n") end
for _, line in ipairs(out.warnings) do io.write("warning: ", line, "\n") end
for _, line in ipairs(out.problems) do io.write("PROBLEM: ", line, "\n") end
io.write(#out.problems == 0 and "replay ok\n" or ("replay found " .. #out.problems .. " problem(s)\n"))
os.exit(#out.problems == 0 and 0 or 1)
