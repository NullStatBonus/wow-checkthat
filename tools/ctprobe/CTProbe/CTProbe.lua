-- Development probe for CheckThat tests/harness.lua assumptions. Not shipped; kept in tools/ctprobe so the measurements can be repeated.
-- The game runs this file first and loads the saved variables afterwards, then fires ADDON_LOADED. A CTProbeDB made here
-- would be replaced by the table from disk, and every line written to the old one would be lost. So the saved table is
-- only touched in ADDON_LOADED (see the event handler below).
local VERSION = 2 -- taint probe (issue 98). The saved file carries it, so a stale copy of this addon shows up in CTProbe.lua.
local log -- CTProbeDB.log, set in ADDON_LOADED
local function say(msg)
    local line = ("%.2f combat=%s %s"):format(GetTime(), tostring(InCombatLockdown()), msg)
    if log then log[#log + 1] = line end
    print("|cff66ccffCTProbe|r " .. line)
end
local function loaded()
    CTProbeDB = CTProbeDB or {}
    CTProbeDB.version = VERSION
    CTProbeDB.log = CTProbeDB.log or {} -- kept across reloads, so a second reload cannot erase earlier lines
    log = CTProbeDB.log
    log[#log + 1] = "---- session start v" .. VERSION
end

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
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, ...)
    if e == "ADDON_LOADED" then
        if (...) == "CTProbe" then loaded() end
    elseif e == "PLAYER_LOGIN" then
        build()
        say("v" .. VERSION .. " loaded. Type /ctp taint run")
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
        if replace() then say("taint: now open the vendor or cast a spell, then /ctp taint off") end
    elseif arg == "off" then restore()
    elseif arg == "entry" then entry()
    else say("taint: use /ctp taint run, or on, off, entry") end
end

SLASH_CTPROBE1 = "/ctp"
SlashCmdList.CTPROBE = function(msg)
    if msg == "build" then build()
    elseif msg == "clear" then if log then wipe(log) end; say("cleared")
    elseif msg == "now" then probe()
    elseif msg:match("^taint") then taint(msg:match("^taint%s*(%S*)"))
    else say("button=" .. tostring(b and b:IsShown()) .. "; /ctp now to probe, /ctp clear to reset") end
end
