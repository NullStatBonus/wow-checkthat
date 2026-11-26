-- Development probe for CheckThat tests/harness.lua assumptions. Not shipped; kept in tools/ctprobe so the measurements can be repeated.
-- The game runs this file first and loads the saved variables afterwards, then fires ADDON_LOADED. A CTProbeDB made here
-- would be replaced by the table from disk, and every line written to the old one would be lost. So the saved table is
-- only touched in ADDON_LOADED (see the event handler below).
local VERSION = 3 -- v2: taint probe (issue 98). v3: lifecycle order (163), tooltip hooks (151), hooksecurefunc taint (154), script time (190), fixtures (153). The saved file carries it, so a stale copy of this addon shows up in CTProbe.lua.
local log -- CTProbeDB.log, set in ADDON_LOADED
local early = {} -- lines made before ADDON_LOADED, written to the log when it arrives
local function say(msg)
    local line = ("%.2f combat=%s %s"):format(GetTime(), tostring(InCombatLockdown()), msg)
    if log then log[#log + 1] = line else early[#early + 1] = line end
    print("|cff66ccffCTProbe|r " .. line)
end
local function loaded()
    CTProbeDB = CTProbeDB or {}
    CTProbeDB.version = VERSION
    CTProbeDB.log = CTProbeDB.log or {} -- kept across reloads, so a second reload cannot erase earlier lines
    log = CTProbeDB.log
    log[#log + 1] = "---- session start v" .. VERSION
    for _, line in ipairs(early) do log[#log + 1] = line end
    early = {}
end

-- Issue 163: the order of the lifecycle events and what the game passes. Every event below is logged with its arguments,
-- IsLoggedIn() and the order number of the session; do a login, a /reload and a logout, then read CTProbeDB.log (or /ctp life).
-- At file scope the saved variables are not loaded yet: the first line says whether CTProbeDB exists then.
local lifeSeq = 0
local LIFE = { "ADDON_LOADED", "VARIABLES_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT",
    "ADDONS_UNLOADING", "SPELLS_CHANGED", "UPDATE_BINDINGS", "PLAYER_ALIVE" }
local function args(...)
    local t = {}
    for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
    return table.concat(t, ",")
end
local function life(e, ...)
    lifeSeq = lifeSeq + 1
    say(("life #%d %s(%s) IsLoggedIn=%s"):format(lifeSeq, e, args(...), tostring(IsLoggedIn and IsLoggedIn())))
end
say(("life file scope: CTProbeDB is %s; IsLoggedIn=%s"):format(type(rawget(_G, "CTProbeDB")), tostring(IsLoggedIn and IsLoggedIn())))

local b, shows, plain = nil, 0, nil
local function build()
    if b or InCombatLockdown() then return end
    b = CreateFrame("Button", "CTProbeButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    b:SetSize(80, 24); b:SetPoint("CENTER", 0, -120); b:SetText("Probe")
    b:SetAttribute("type", "macro"); b:SetAttribute("macrotext", "/run print('probe click')")
    b:HookScript("OnShow", function() shows = shows + 1; if shows <= 12 then say("button OnShow #" .. shows) end end)
    b:HookScript("OnHide", function() say("button OnHide") end)
    RegisterStateDriver(b, "visibility", "[combat] hide; show")
    plain = CreateFrame("Frame", "CTProbePlain", UIParent)
    say("built; build=" .. table.concat({ GetBuildInfo() }, " ") .. " shown=" .. tostring(b:IsShown()))
end

local function try(label, f, ...)
    local ok, err = pcall(f, ...)
    say(("%s: %s%s"):format(label, ok and "no error" or "ERROR ", ok and "" or tostring(err)))
end

local function probe()
    if not b then say("no button; build it out of combat first") return end
    say("probe start; button shown=" .. tostring(b:IsShown()) .. " macrotext=" .. tostring(b:GetAttribute("macrotext")))
    try("protected SetAttribute", b.SetAttribute, b, "macrotext", "/run print('changed in combat')")
    say("  macrotext now=" .. tostring(b:GetAttribute("macrotext")))
    try("protected Show", b.Show, b); say("  shown now=" .. tostring(b:IsShown()))
    try("protected Hide", b.Hide, b); say("  shown now=" .. tostring(b:IsShown()))
    try("protected SetPoint", b.SetPoint, b, "CENTER", UIParent, "CENTER", 0, -140)
    try("protected ClearAllPoints", b.ClearAllPoints, b)
    try("protected SetSize", b.SetSize, b, 90, 24); say("  width now=" .. tostring(b:GetWidth()))
    try("plain Hide", plain.Hide, plain)
    try("plain Show", plain.Show, plain)
    say("probe end")
end

local ev = CreateFrame("Frame")
local watched = {}
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
    "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "ADDONS_UNLOADING", "SPELLS_CHANGED", "UPDATE_BINDINGS", "PLAYER_ALIVE" }) do
    local ok = pcall(ev.RegisterEvent, ev, e)
    watched[e] = ok
end
local isLife = {}
for _, e in ipairs(LIFE) do isLife[e] = true end
ev:SetScript("OnEvent", function(_, e, ...)
    if e == "ADDON_LOADED" then
        if (...) == "CTProbe" then loaded() end
        life(e, ...)
    elseif isLife[e] and e ~= "PLAYER_LOGIN" then
        life(e, ...)
    elseif e == "PLAYER_LOGIN" then
        life(e, ...)
        build()
        say("v" .. VERSION .. " loaded. /ctp taint run, tooltip, budget, record, life")
    elseif e == "PLAYER_REGEN_DISABLED" then
        shows = 0
        say("event PLAYER_REGEN_DISABLED; button shown=" .. tostring(b and b:IsShown()))
        C_Timer.After(1, probe) -- one second into combat
    elseif e == "PLAYER_REGEN_ENABLED" then
        shows = 0
        say("event PLAYER_REGEN_ENABLED; button shown=" .. tostring(b and b:IsShown()))
        C_Timer.After(2, function() say("2 s after combat; button shown=" .. tostring(b and b:IsShown())) end)
    else
        say("event " .. e .. " " .. table.concat({ tostring((...)), tostring(select(2, ...)) }, " "))
    end
end)

-- Issue 98: does replacing a global, or calling an addon function from insecure code, taint?
-- /ctp taint run     the whole test in one go, no clicks: it needs no protected action. Then /reload (the taint stays until then).
-- /ctp taint on|off  the same steps by hand, with time in between for you to open a vendor or click a spell.
-- /ctp taint entry   call a function this addon registered, from insecure code, the way CheckThat does.
-- issecurevariable(name) returns isSecure and the name of the addon that tainted it. That answer is the measurement.
local realGetMoney
local function secure(name)
    local ok, isSecure, by = pcall(issecurevariable, name)
    if not ok then return "issecurevariable failed: " .. tostring(isSecure) end
    return ("secure=%s by=%s"):format(tostring(isSecure), tostring(by))
end
local function replace()
    if realGetMoney then say("taint: GetMoney is already replaced") return false end
    realGetMoney = GetMoney
    say("taint: GetMoney before: " .. secure("GetMoney"))
    GetMoney = function(...) return realGetMoney(...) end
    say("taint: GetMoney after replacing: " .. secure("GetMoney"))
    return true
end
local function restore()
    if not realGetMoney then say("taint: GetMoney is not replaced") return end
    GetMoney = realGetMoney; realGetMoney = nil
    say("taint: GetMoney after restoring the original: " .. secure("GetMoney"))
end
-- An entry that writes a global when called. A global that this addon wrote at load is always tainted by it, so the
-- check that means something is the one made after the call: did calling the function taint anything it did not write itself?
function CTProbeEntry(a, b) CTProbeEntryRan = (CTProbeEntryRan or 0) + 1; return a + b end
local function entry()
    local ok, r = pcall(_G.CTProbeEntry, 2, 3)
    say(("taint: entry call ok=%s result=%s; GetMoney %s; GetTime %s; the global it wrote, CTProbeEntryRan %s"):format(
        tostring(ok), tostring(r), secure("GetMoney"), secure("GetTime"), secure("CTProbeEntryRan")))
end
local function taint(arg)
    if InCombatLockdown() then say("taint: refused in combat") return end
    if arg == "run" then
        say("taint: v" .. VERSION .. " run start")
        entry() -- first, so its readings are not changed by the replacement below
        if replace() then restore() end
        say("taint: run end. Type /reload now: a global that addon code wrote stays tainted until then.")
    elseif arg == "on" then
        if replace() then say("taint: GetMoney is replaced. Now open a vendor and buy something (or cast a spell), out of combat and then in combat; ADDON_ACTION_BLOCKED lines show here (issue 154). Then /ctp taint off") end
    elseif arg == "off" then restore()
    elseif arg == "entry" then entry()
    elseif arg == "hook" then
        -- Issue 154: does hooksecurefunc taint the name it hooks? UnitName is hooked because it takes an argument.
        say("taint: UnitName before hooking: " .. secure("UnitName"))
        local got
        local ok, err = pcall(hooksecurefunc, "UnitName", function(...) got = args(...) end)
        say("taint: hooksecurefunc ok=" .. tostring(ok) .. (ok and "" or " " .. tostring(err)))
        say("taint: UnitName after hooking: " .. secure("UnitName"))
        local n = UnitName("player")
        say(("taint: the hook ran=%s with the arguments (%s); the original returned a %s. /reload to remove the hook."):format(tostring(got ~= nil), tostring(got), type(n)))
    elseif arg == "hookerror" then
        -- Does a throwing hook change what the original returns?
        pcall(hooksecurefunc, "GetTime", function() error("CTProbe hook error, on purpose", 0) end)
        local ok, t = pcall(GetTime)
        say(("taint: after a throwing hook, GetTime() ok=%s returned a %s; %s. /reload to remove the hook."):format(tostring(ok), type(t), secure("GetTime")))
    else say("taint: use /ctp taint run, or on, off, entry, hook, hookerror") end
end

-- Issue 151: which tooltip hook path does this client run? The OnTooltipSetItem script, TooltipDataProcessor.AddTooltipPostCall,
-- both or neither. Both are registered at file scope, then /ctp tooltip sets the tooltip to an item and counts what fired. It also
-- logs whether the tooltip is shown after SetOwner, SetText and AddLine (CheckThat's fake tooltip starts hidden and does not show it).
local tipFired, tipHooks = { script = 0, processor = 0 }, {}
if GameTooltip and GameTooltip.HookScript then
    tipHooks.script = pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", function() tipFired.script = tipFired.script + 1 end)
end
if rawget(_G, "TooltipDataProcessor") and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    tipHooks.processor = pcall(TooltipDataProcessor.AddTooltipPostCall, Enum.TooltipDataType.Item, function() tipFired.processor = tipFired.processor + 1 end)
end
local function tooltip()
    local tip = GameTooltip
    if not (tip and tip.SetOwner) then say("tooltip: this client has no GameTooltip") return end
    say(("tooltip: OnTooltipSetItem hook registered=%s; TooltipDataProcessor is a %s, Enum.TooltipDataType is a %s, post call registered=%s"):format(
        tostring(tipHooks.script), type(rawget(_G, "TooltipDataProcessor")), type(Enum and Enum.TooltipDataType), tostring(tipHooks.processor)))
    local function state(what) say(("tooltip: %s: IsShown=%s NumLines=%s"):format(what, tostring(tip:IsShown()), tostring(tip:NumLines()))) end
    state("before SetOwner"); tip:SetOwner(UIParent, "ANCHOR_CURSOR"); state("after SetOwner")
    tip:SetText("CTProbe title"); state("after SetText"); tip:AddLine("CTProbe line"); state("after AddLine")
    tip:Show(); state("after Show")
    tipFired.script, tipFired.processor = 0, 0
    local ok, err = pcall(tip.SetHyperlink, tip, "item:6948")
    say(("tooltip: SetHyperlink item:6948 ok=%s%s; hooks fired at once: script=%d post call=%d; NumLines=%s"):format(
        tostring(ok), ok and "" or " " .. tostring(err), tipFired.script, tipFired.processor, tostring(tip:NumLines())))
    C_Timer.After(0.5, function()
        say(("tooltip: 0.5 s later: script=%d post call=%d; line 1 is %s"):format(tipFired.script, tipFired.processor, tostring(_G.GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText())))
        tip:Hide()
    end)
end

-- Issue 190: how much work can one script do before the game stops it? Each stage runs in its own timer callback, in doubling sizes,
-- for a plain loop and for a loop that makes a call each turn. It stops a family when the next stage would take longer than the cap
-- (4 s; /ctp budget force raises it to 30 s: the game may freeze for that long). The log gives n and milliseconds for each stage,
-- and the error when the game stops a script.
local clock = debugprofilestop or function() return GetTime() * 1000 end
local FAMILIES = {
    { "loop", function(n) local x = 0; for i = 1, n do x = x + i end return x end },
    { "calls", function(n) local abs, x = math.abs, 0; for i = 1, n do x = x + abs(i) end return x end },
}
local function budget(arg)
    local cap = (CTProbeDB and CTProbeDB.budgetCapMs) or (arg == "force" and 30000 or 4000)
    local rate = {}
    local function stage(fi, n, lastMs)
        local fam = FAMILIES[fi]
        if not fam then
            local loop, calls = rate.loop, rate.calls
            say(("budget: done. loop %s iterations per ms, calls %s per ms%s"):format(tostring(loop), tostring(calls),
                (loop and calls) and (", so one call costs about %.1f loop iterations"):format(loop / calls) or ""))
            return
        end
        if lastMs and lastMs * 2 > cap then say(("budget: %s stops at n=%d: the next stage would take over %d ms"):format(fam[1], math.floor(n / 2), cap)); return stage(fi + 1, 100000) end
        local t0 = clock()
        local ok, err = pcall(fam[2], n)
        local ms = clock() - t0
        say(("budget: %s n=%d ok=%s %.0f ms%s"):format(fam[1], n, tostring(ok), ms, ok and "" or " " .. tostring(err)))
        if ok and ms > 0 then rate[fam[1]] = math.floor(n / ms) end
        if not ok then return C_Timer.After(0.2, function() stage(fi + 1, 100000) end) end
        C_Timer.After(0.2, function() stage(fi, n * 2, ms) end)
    end
    say("budget: start, cap " .. cap .. " ms per stage")
    stage(1, 100000)
end

-- Issue 153: what do read-only calls return in this client? /ctp record writes CTProbeDB.fixtures[label] = { n, values }. A value
-- that is personal (money, names, counts) is recorded by its type only.
local FIXTURES = {
    { "GetBuildInfo()", function() return GetBuildInfo() end },
    { "GetLocale()", function() return GetLocale() end },
    { "GetCurrentRegion()", function() return GetCurrentRegion() end },
    { "GetItemInfo(6948)", function() return GetItemInfo(6948) end },
    { "C_Item.GetItemInfo(6948)", function() return C_Item.GetItemInfo(6948) end },
    { "GetContainerNumSlots(0)", function() return GetContainerNumSlots(0) end },
    { "C_Container.GetContainerNumSlots(0)", function() return C_Container.GetContainerNumSlots(0) end },
    { "UnitClass(player)", function() return UnitClass("player") end },
    { "UnitRace(player)", function() return UnitRace("player") end },
    { "UnitFactionGroup(player)", function() return UnitFactionGroup("player") end },
    { "IsLoggedIn()", function() return IsLoggedIn() end },
    { "InCombatLockdown()", function() return InCombatLockdown() end },
    { "GetMoney()", function() return GetMoney() end, true },
    { "GetItemCount(6948)", function() return GetItemCount(6948) end, true },
    { "GetTime()", function() return GetTime() end, true },
    { "GetServerTime()", function() return GetServerTime() end, true },
    { "UnitName(player)", function() return UnitName("player") end, true },
    { "GetRealmName()", function() return GetRealmName() end, true },
}
local function shape(v, typeOnly)
    local t = type(v)
    if typeOnly or t == "function" or t == "userdata" or t == "thread" then return { type = t } end
    if t == "table" then
        local copy, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 8 then break end
            copy[tostring(k)] = type(x) == "table" and { type = "table" } or { type = type(x), value = x }
        end
        return { type = t, value = copy }
    end
    return { type = t, value = v }
end
local function record()
    if not CTProbeDB then say("record: saved variables are not loaded yet") return end
    CTProbeDB.fixtures = {}
    local good, bad = 0, 0
    for _, f in ipairs(FIXTURES) do
        local r = { pcall(f[2]) }
        local values = {}
        for i = 2, #r do values[#values + 1] = shape(r[i], f[3]) end
        local ok = r[1]
        CTProbeDB.fixtures[f[1]] = ok and { n = math.max(#r - 1, 0), values = values, typeOnly = f[3] or nil } or { error = tostring(r[2]) }
        if ok then good = good + 1 else bad = bad + 1 end
    end
    CTProbeDB.fixturesBuild = table.concat({ GetBuildInfo() }, " ")
    say(("record: %d calls recorded, %d raised an error (see CTProbeDB.fixtures); build %s"):format(good, bad, CTProbeDB.fixturesBuild))
end

SLASH_CTPROBE1 = "/ctp"
SlashCmdList.CTPROBE = function(msg)
    if msg == "build" then build()
    elseif msg == "clear" then if log then wipe(log) end; say("cleared")
    elseif msg == "now" then probe()
    elseif msg == "tooltip" then tooltip()
    elseif msg == "record" then record()
    elseif msg:match("^budget") then budget(msg:match("^budget%s*(%S*)"))
    elseif msg == "life" then
        for _, l in ipairs(log or early) do if l:find("life", 1, true) then print(l) end end -- the whole log, all sessions
    elseif msg:match("^taint") then taint(msg:match("^taint%s*(%S*)"))
    else say("button=" .. tostring(b and b:IsShown()) .. "; /ctp now, taint, tooltip, budget, record, life, clear") end
end
