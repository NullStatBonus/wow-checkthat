-- The in-game probe (tools/ctprobe) run in the fake client: every /ctp command must run without an error and write the lines the
-- measurements are read from. It proves the probe works, not what the game answers.
local loadfile = loadfile
local ns, test, T, finish, H = dofile("tests/harness.lua")()
local L51 = dofile("tools/lua51_check.lua")
local PATH = "tools/ctprobe/CTProbe/CTProbe.lua"

local function probe(opts)
    local restore = H.snapshot()
    T.finally(restore)
    opts.client = opts.client or "era"
    opts.clock = {}
    local st = H.stubClient(opts)
    local create = _G.CreateFrame -- the shared fake client keeps no record of registered events: the runner adds one the same way
    _G.CreateFrame = function(...)
        local f = create(...)
        f.events = {}
        rawset(f, "RegisterEvent", function(self, ev) self.events[ev] = true end)
        return f
    end
    _G.CTProbeDB = nil
    assert(loadfile(PATH))("CTProbe", {})
    local frame
    for _, f in ipairs(st.frames) do if rawget(f, "scripts") and f.scripts.OnEvent and rawget(f, "events") then frame = f end end
    local function fire(e, ...) frame.scripts.OnEvent(frame, e, ...) end
    fire("ADDON_LOADED", "CTProbe")
    return st, fire
end
local function has(pattern) for _, l in ipairs(CTProbeDB.log) do if l:find(pattern, 1, true) then return l end end end

test("the probe file is Lua 5.1", function()
    T.same(L51.check(PATH), {}, "Lua 5.1 findings")
end)

test("the lifecycle events are logged in order with their arguments and IsLoggedIn, and the file-scope line is kept", function()
    local st, fire = probe({})
    fire("VARIABLES_LOADED"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD", true, false)
    fire("PLAYER_LEAVING_WORLD"); fire("PLAYER_LOGOUT"); fire("ADDONS_UNLOADING", false)
    T.ok(has("life file scope: CTProbeDB is nil"), "the line made before ADDON_LOADED reaches the log")
    local order = {}
    for _, l in ipairs(CTProbeDB.log) do local n, e, a = l:match("life #(%d+) (%u[%u_]*)%(([^)]*)%)"); if n then order[#order + 1] = e .. "(" .. a .. ")" end end
    T.same(order, { "ADDON_LOADED(CTProbe)", "VARIABLES_LOADED()", "PLAYER_LOGIN()", "PLAYER_ENTERING_WORLD(true,false)", "PLAYER_LEAVING_WORLD()", "PLAYER_LOGOUT()", "ADDONS_UNLOADING(false)" })
    T.ok(has("IsLoggedIn="), "IsLoggedIn is logged with each event")
    SlashCmdList.CTPROBE("life")
    T.ok(#st.said > 0, "/ctp life prints")
end)

test("/ctp record stores the read-only calls, and personal values by type only", function()
    probe({})
    _G.GetMoney = function() return 12345 end
    _G.UnitName = function() return "Secretname" end
    SlashCmdList.CTPROBE("record")
    local fx = CTProbeDB.fixtures
    T.ok(fx["GetBuildInfo()"] and fx["GetBuildInfo()"].n >= 2, "GetBuildInfo returns several values")
    T.eq(fx["GetBuildInfo()"].values[1].type, "string")
    T.eq(fx["GetMoney()"].typeOnly, true); T.eq(fx["GetMoney()"].values[1].type, "number"); T.eq(fx["GetMoney()"].values[1].value, nil, "money is recorded by type only")
    T.eq(fx["UnitName(player)"].typeOnly, true); T.eq(fx["UnitName(player)"].values[1].value, nil, "a character name is never recorded")
    T.ok(has("record:") and has("calls recorded"), "the summary line")
    T.ok(CTProbeDB.fixturesBuild:find("%d+%.%d+%.%d+"), CTProbeDB.fixturesBuild)
end)

test("/ctp tooltip logs the state after each step and what fired", function()
    local st = probe({})
    SlashCmdList.CTPROBE("tooltip")
    T.ok(has("tooltip: before SetOwner: IsShown=false"), "the tooltip starts hidden")
    T.ok(has("after SetText: IsShown="), "the state after SetText"); T.ok(has("NumLines=2"), "a title and a line")
    T.ok(has("SetHyperlink item:6948 ok="), "the hyperlink call is logged"); T.ok(has("hooks fired at once"), "the hook counters")
    st.advance(1)
    T.ok(has("0.5 s later"), "the delayed reading")
end)

test("/ctp budget runs its stages in separate timers, stops at the cap and reports the rates", function()
    local st = probe({})
    CTProbeDB.budgetCapMs = 5 -- a stage is allowed 5 ms, so the doubling stops after a few stages and the test stays quick
    SlashCmdList.CTPROBE("budget")
    T.ok(has("budget: start"))
    for _ = 1, 60 do st.advance(1); if has("budget: done") then break end end
    T.ok(has("budget: loop n=100000 ok=true"), "the first stage of the loop family")
    T.ok(has("budget: calls n=100000 ok=true"), "the first stage of the calls family")
    T.ok(has("stops at n="), "a family stops when the next stage would pass the cap")
    T.ok(has("budget: done. loop "), "the summary with the rates")
end)

test("/ctp taint hook measures hooksecurefunc, and a throwing hook leaves the original's result", function()
    local st = probe({ taint = true })
    SlashCmdList.CTPROBE("taint hook")
    T.ok(has("UnitName before hooking: secure=true"), "before"); T.ok(has("hooksecurefunc ok=true"))
    T.ok(has("UnitName after hooking: secure=true"), "the harness leaves a hooked name secure: " .. tostring(has("after hooking")))
    T.ok(has("the hook ran=true with the arguments (player)"), tostring(has("the hook ran")))
    rawset(_G, "geterrorhandler", function() return function() end end)
    SlashCmdList.CTPROBE("taint hookerror")
    T.ok(has("GetTime() ok=true returned a number"), tostring(has("after a throwing hook")))
end)

test("/ctp taint run still measures the replaced global, and the other commands do not raise", function()
    probe({ taint = true })
    SlashCmdList.CTPROBE("taint run")
    T.ok(has("GetMoney after replacing: secure=false"), "a replaced game global reads insecure when the harness models taint")
    T.ok(has("GetMoney after restoring the original: secure=false"), "and stays so")
    SlashCmdList.CTPROBE(""); SlashCmdList.CTPROBE("clear")
end)

finish()
