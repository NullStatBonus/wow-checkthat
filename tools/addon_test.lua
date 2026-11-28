-- The Lua side of ct test (#273): runs one test file of an addon against one TOC. Each test is a fresh load of the addon in the
-- fake client at the newest offline level, with one hook step that calls the test function with ctx (docs/addon-tests.md).
--
--   luajit tools/addon_test.lua JOB.json
--   JOB: { "toc": path, "file": path, "out": path, "interface": n?, "addon": name?, "testDir": path?, "name": text?, "recordings": folder? }
--
-- Writes { "format": 1, "file", "interface", "tests": [ { "name", "ok", "detail" } ], "nilReads": [names], "error"? } to JOB.out, so
-- what the test file writes to stdout stays its own, and exits 1 when a test fails or the file cannot run. The test file runs with the
-- user's permissions, as a hooks file does.
local here = arg[0]:match("^(.*)[/\\]tools[/\\][^/\\]*$") or "."
local jns = {}
assert(loadfile(here .. "/CheckThat/Model/Json.lua"))("CheckThat", jns)
local Json = jns.Json
local Runner = dofile(here .. "/tools/entry_runner.lua")

local f = assert(io.open(arg[1], "r"))
local job = assert(Json.Decode(f:read("*a")))
f:close()

local OPTIONS = { mocks = true, savedVariables = true, checkThat = true }
local LOAD_ORDER = { early = true, late = true, missing = true } -- when CheckThat's global is there (docs/addon-tests.md)
local tests = {}
-- The test file's `...`: fields are only added, never removed or changed in meaning.
local ct = { API = 1 }
function ct.test(name, options, fn)
    if fn == nil then fn, options = options, nil end
    if type(name) ~= "string" or name == "" then error("ct.test: the first value is the test's name", 2) end
    if type(fn) ~= "function" then error(("ct.test %q: the last value is the test function"):format(name), 2) end
    if options ~= nil and type(options) ~= "table" then error(("ct.test %q: the options are a table"):format(name), 2) end
    for k in pairs(options or {}) do
        if not OPTIONS[k] then error(("ct.test %q: unknown option %s (mocks, savedVariables or checkThat)"):format(name, tostring(k)), 2) end
    end
    local order = (options or {}).checkThat
    if order ~= nil and not LOAD_ORDER[order] then
        error(("ct.test %q: checkThat is \"early\", \"late\" or \"missing\", got %s"):format(name, tostring(order)), 2)
    end
    tests[#tests + 1] = { name = name, options = options or {}, fn = fn }
end

local out = { format = 1, file = job.file, tests = {}, nilReads = {} }
local function finish(code)
    local of = assert(io.open(job.out, "w"))
    of:write(Json.Encode(out), "\n")
    of:close()
    os.exit(code)
end
-- require("helper") finds the addon's tests/helper.lua.
if job.testDir then package.path = job.testDir .. "/?.lua;" .. package.path end

local chunk, lerr = loadfile(job.file)
if not chunk then out.error = "the test file cannot be loaded: " .. tostring(lerr); finish(1) end
local ok, err = pcall(chunk, ct)
if not ok then out.error = "the test file raised " .. tostring(err); finish(1) end
if #tests == 0 then out.error = "the test file registers no test (ct.test)"; finish(1) end

local seen, failed = {}, false
for _, t in ipairs(tests) do
    if not job.name or t.name:find(job.name, 1, true) then
        local spec = { toc = job.toc, level = Runner.LEVEL, mocks = t.options.mocks, savedVariables = t.options.savedVariables,
            recordings = job.recordings, steps = { { hook = "test" } } }
        local rok, r = pcall(Runner.run, spec, { root = here, hooks = { test = t.fn }, hooksFile = job.file, testDir = job.testDir,
            interface = job.interface, addonName = job.addon, checkThat = t.options.checkThat or "early" })
        local res = { name = t.name, ok = false }
        if not rok then
            res.detail = "the runner failed: " .. tostring(r)
        else
            out.interface = out.interface or r.interface
            for _, n in ipairs(r.nilReads or {}) do seen[n] = true end
            res.ok = r.ok
            for _, s in ipairs(r.steps) do
                if not s.ok then res.detail = (s.kind == "load" and "the addon did not load: " or "") .. tostring(s.detail); break end
            end
        end
        if not res.ok then failed = true end
        out.tests[#out.tests + 1] = res
    end
end
for n in pairs(seen) do out.nilReads[#out.nilReads + 1] = n end
table.sort(out.nilReads)
finish(failed and 1 or 0)
