-- Development probe for CheckThat tests/harness.lua assumptions. Not shipped; kept in tools/ctprobe so the measurements can be repeated.
-- The game runs this file first and loads the saved variables afterwards, then fires ADDON_LOADED. A CTProbeDB made here
-- would be replaced by the table from disk, and every line written to the old one would be lost. So the saved table is
-- only touched in ADDON_LOADED (see the event handler below).
local VERSION = 9 -- v9: /ctp record <call> records one read-only call a developer names (#214). v8: table returns kept three levels deep, table arguments stored, Forever auction house scenes (browse, itemsearch, commodity) (#234). v7: last update wins per opening, headers skipped, trainer filter and kind recorded, auction waits for complete rows, old window rows cleared at arm, record status (review of #240). v6: one window opening fills one scene; a nil IsTradeskillTrainer is a class trainer. v5: two scenes per window, money, item info for vendor rows, trainer level, auction links (issue 240). v4: armed window capture and candidate items (ctprobe-window-recordings). v2: taint probe (issue 98). v3: lifecycle order (163), tooltip hooks (151), hooksecurefunc taint (154), script time (190), fixtures (153). The saved file carries it, so a stale copy of this addon shows up in CTProbe.lua.
local log -- CTProbeDB.log, set in ADDON_LOADED
local early = {} -- lines made before ADDON_LOADED, written to the log when it arrives
local realGetTime = GetTime -- say() reads the clock through this, so a hook on GetTime from /ctp taint hookerror cannot reach the log
local function say(msg)
    local line = ("%.2f combat=%s %s"):format(realGetTime(), tostring(InCombatLockdown()), msg)
    if log then log[#log + 1] = line else early[#early + 1] = line end
    print("|cff66ccffCTProbe|r " .. line)
end
local function loaded()
    CTProbeDB = CTProbeDB or {}
    CTProbeDB.version = VERSION
    CTProbeDB.armed = nil -- arming lasts one session, so a scene left open does not record on a later visit
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

local opened = {} -- window kind -> the scene this opening fills; its _SHOW and _CLOSED events clear it, so one window fills one scene
local windowEvents = {} -- window event -> true when this client has it
local WINDOW_EVENT, ITEM_FIXTURES, capture, store, captureModern, MODERN_EVENT -- set further down, where the calls they use are defined
local ev = CreateFrame("Frame")
local watched = {}
for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
    "VARIABLES_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_LEAVING_WORLD", "PLAYER_LOGOUT", "ADDONS_UNLOADING", "SPELLS_CHANGED", "UPDATE_BINDINGS", "PLAYER_ALIVE" }) do
    local ok = pcall(ev.RegisterEvent, ev, e)
    watched[e] = ok
end
for _, e in ipairs({ "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED", "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "AUCTION_ITEM_LIST_UPDATE", "GET_ITEM_INFO_RECEIVED",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "COMMODITY_SEARCH_RESULTS_UPDATED", "AUCTION_HOUSE_CLOSED" }) do
    windowEvents[e] = pcall(ev.RegisterEvent, ev, e) -- a client without the event raises here; arm() stores why that window is missing
end
local isLife = {}
for _, e in ipairs(LIFE) do isLife[e] = true end
ev:SetScript("OnEvent", function(_, e, ...)
    if e == "ADDON_LOADED" then
        if (...) == "CTProbe" then loaded(); life(e, ...) end -- the other addons' loads are not logged
    elseif isLife[e] and e ~= "PLAYER_LOGIN" then
        life(e, ...)
    elseif e == "PLAYER_LOGIN" then
        life(e, ...)
        build()
        say("v" .. VERSION .. " loaded. /ctp taint run, tooltip, budget, record, record <call>, record arm, life")
    elseif e == "PLAYER_REGEN_DISABLED" then
        shows = 0
        say("event PLAYER_REGEN_DISABLED; button shown=" .. tostring(b and b:IsShown()))
        C_Timer.After(1, probe) -- one second into combat
    elseif e == "PLAYER_REGEN_ENABLED" then
        shows = 0
        say("event PLAYER_REGEN_ENABLED; button shown=" .. tostring(b and b:IsShown()))
        C_Timer.After(2, function() say("2 s after combat; button shown=" .. tostring(b and b:IsShown())) end)
    elseif e == "AUCTION_HOUSE_CLOSED" then
        for _, scene in pairs(MODERN_EVENT) do opened[scene] = nil end
    elseif MODERN_EVENT[e] then
        captureModern(MODERN_EVENT[e], ...)
    elseif WINDOW_EVENT[e] then
        local win = WINDOW_EVENT[e]
        if e == "MERCHANT_SHOW" or e == "TRAINER_SHOW" or e == "MERCHANT_CLOSED" or e == "TRAINER_CLOSED" then opened[win] = nil end
        if CTProbeDB and CTProbeDB.armed and not e:find("_CLOSED$") then capture(win, e) end -- capture checks the window's scenes: a filled plain scene leaves the other armed
    elseif e == "GET_ITEM_INFO_RECEIVED" then
        local id = ...
        if CTProbeDB and CTProbeDB.fixtures and ITEM_FIXTURES[id] then
            for _, f in ipairs(ITEM_FIXTURES[id]) do store(f[1], f[2], f[3], f[4]) end
            say(("item %d delivered; its GetItemInfo records are replaced"):format(id))
            if opened.merchant and CTProbeDB.armed then capture("merchant", e) end -- the open vendor's rows now have the name and link
        end
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
        local armed = true -- the hook stays until /reload, so it raises only for the one call below
        pcall(hooksecurefunc, "GetTime", function() if armed then error("CTProbe hook error, on purpose", 0) end end)
        local ok, t = pcall(GetTime)
        armed = false
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
    local cap = arg == "force" and 30000 or (CTProbeDB and CTProbeDB.budgetCapMs) or 4000 -- budgetCapMs is for the tests
    local rate = {}
    local function stage(fi, n, lastMs)
        local fam = FAMILIES[fi]
        if not fam then
            local loop, calls = rate.loop, rate.calls
            say(("budget: done. loop %s iterations per ms, calls %s per ms%s"):format(loop and tostring(loop) or "unknown", calls and tostring(calls) or "unknown",
                (loop and calls and calls > 0) and (", so one call costs about %.1f loop iterations"):format(loop / calls) or " (no stage took a measurable time)"))
            return
        end
        if lastMs and lastMs * 2 > cap then say(("budget: %s stops at n=%d: the next stage would take over %d ms"):format(fam[1], math.floor(n / 2), cap)); return stage(fi + 1, 100000) end
        say(("budget: starting %s n=%d"):format(fam[1], n)) -- a stage the game aborts writes no result line: this one shows where it stopped
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
local ITEMS = { 12640, 12784 } -- candidate armor (Lionheart Helm) and weapon (Arcanite Reaper); the reviewer keeps those that sell for more than 1 silver
ITEM_FIXTURES = {}
for _, id in ipairs(ITEMS) do
    ITEM_FIXTURES[id] = {
        { ("GetItemInfo(%d)"):format(id), function() return GetItemInfo(id) end },
        { ("C_Item.GetItemInfo(%d)"):format(id), function() return C_Item.GetItemInfo(id) end },
    }
    for _, f in ipairs(ITEM_FIXTURES[id]) do FIXTURES[#FIXTURES + 1] = f end
end
-- A table is copied three levels deep with up to 32 keys each (an auction result's itemKey is the third level). cut marks a table that
-- was copied in part, so ct.py does not mistake a sample for the whole answer.
local function shape(v, typeOnly, depth)
    local t = type(v)
    if typeOnly or t == "function" or t == "userdata" or t == "thread" then return { type = t } end
    if t == "table" then
        depth = depth or 1
        if depth > 3 then return { type = t, cut = true } end
        local copy, n, cut = {}, 0, nil
        for k, x in pairs(v) do
            n = n + 1
            if n > 32 then cut = true; break end
            local s = shape(x, nil, depth + 1)
            if s.cut then cut = true end
            copy[tostring(k)] = s
        end
        return { type = t, value = copy, cut = cut }
    end
    return { type = t, value = v }
end
local function pack(...) return { n = select("#", ...), ... } end
-- Runs fn once and stores what it returned under label. n counts the nils too, so a nil before a value is kept. window tags a call that
-- was recorded with a window open; ct.py recordings carries the tag into the recording.
store = function(label, fn, typeOnly, window, scene, args)
    local r = pack(pcall(fn))
    local values = {}
    for i = 2, r.n do values[#values + 1] = shape(r[i], typeOnly) end
    local entry = r[1] and { n = math.max(r.n - 1, 0), values = values, typeOnly = typeOnly or nil, window = window, scene = scene } or { error = tostring(r[2]), window = window, scene = scene }
    if args then -- a table argument (an auction itemKey) cannot be read back from the label, so the arguments are stored with the call
        entry.args = {}
        for i = 1, args.n or #args do entry.args[i] = shape(args[i]) end
    end
    CTProbeDB.fixtures[label] = entry
    return entry
end
local function record()
    if not CTProbeDB then say("record: saved variables are not loaded yet") return end
    local kept = {}
    for label, entry in pairs(CTProbeDB.fixtures or {}) do if entry.window or entry.picked then kept[label] = entry end end -- what the windows and /ctp record <call> recorded stays
    CTProbeDB.fixtures = kept
    local good, bad = 0, 0
    for _, id in ipairs(ITEMS) do
        local request = C_Item and C_Item.RequestLoadItemDataByID
        if request then pcall(request, id) end -- an uncached item returns nothing until the client has loaded it
    end
    for _, f in ipairs(FIXTURES) do
        if store(f[1], f[2], f[3]).error then bad = bad + 1 else good = good + 1 end
    end
    CTProbeDB.fixturesBuild = table.concat({ GetBuildInfo() }, " ")
    say(("record: %d calls recorded, %d raised an error (see CTProbeDB.fixtures); build %s"):format(good, bad, CTProbeDB.fixturesBuild))
end

-- Armed window capture. Vendor, trainer and auction calls return nothing unless their window is open, so /ctp record arm waits for the
-- window's events and records the count and the first rows then. Only read-only calls are made: the probe never calls anything that
-- changes state. A call the client lacks is stored as an error entry, which ct.py recordings reports as left out.
-- Scenes: each window kind has slots, one per kind of NPC. A vendor that sells armor or weapons fills gear, any other vendor the plain
-- vendor scene; a class trainer (IsTradeskillTrainer() answers nil or false) fills class, a profession trainer the plain trainer scene;
-- the auction list has one scene. The plain scene keeps the v4 labels; another scene's labels start with its name
-- ("gear:GetMerchantItemInfo(1)"). One opening of a window fills one scene, and every later update of that opening records it again
-- (the last one wins), so names and links that arrive late are kept. Each scene stores the balance ("<scene>:GetMoney()"), and each
-- vendor row's item gets GetItemInfo and C_Item.GetItemInfo.
local ROWS = 3
local WINDOWS = {
    merchant = { count = "GetMerchantNumItems", rows = { "GetMerchantItemInfo", "GetMerchantItemLink", "GetMerchantItemID", "C_MerchantFrame.GetItemInfo" },
        money = true, scenes = { "gear", "merchant" } },
    trainer = { count = "GetNumTrainerServices", rows = { "GetTrainerServiceInfo", "GetTrainerServiceCost", "GetTrainerServiceSkillReq", "GetTrainerServiceLevelReq" },
        money = true, scenes = { "class", "trainer" } },
    auction = { count = "GetNumAuctionItems", arg = "list", rows = { "GetAuctionItemInfo", "GetAuctionItemLink" }, scenes = { "auction" } }, -- the plain word list, so the label reads back
}
-- Forever's auction house (C_AuctionHouse): three windows, each one scene with plain labels, tagged auction. Their events carry the search.
local MODERN = {
    browse = { event = "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", calls = function() return { { "C_AuctionHouse.HasFullBrowseResults" }, { "C_AuctionHouse.GetBrowseResults" } } end },
    itemsearch = { event = "ITEM_SEARCH_RESULTS_UPDATED", calls = function(key)
        local list = { { "C_AuctionHouse.GetNumItemSearchResults", key }, { "C_AuctionHouse.HasFullItemSearchResults", key }, { "C_AuctionHouse.GetItemKeyInfo", key } }
        for i = 1, ROWS do list[#list + 1] = { "C_AuctionHouse.GetItemSearchResultInfo", key, i } end
        return list
    end },
    commodity = { event = "COMMODITY_SEARCH_RESULTS_UPDATED", calls = function(id)
        local list = { { "C_AuctionHouse.GetNumCommoditySearchResults", id }, { "C_AuctionHouse.HasFullCommoditySearchResults", id } }
        for i = 1, ROWS do list[#list + 1] = { "C_AuctionHouse.GetCommoditySearchResultInfo", id, i } end
        return list
    end },
}
MODERN_EVENT = {} -- declared at the top, where the event handler reads it
for scene, m in pairs(MODERN) do MODERN_EVENT[m.event] = scene end
local SCENE_ROWS = { class = 10 } -- a class trainer lists several ranks of one spell, so more rows are kept
local FILTERS = { "available", "unavailable", "used" } -- the trainer window's filter boxes; a hidden row is not in the count
WINDOW_EVENT = { MERCHANT_SHOW = "merchant", MERCHANT_UPDATE = "merchant", MERCHANT_CLOSED = "merchant", TRAINER_SHOW = "trainer",
    TRAINER_UPDATE = "trainer", TRAINER_CLOSED = "trainer", AUCTION_ITEM_LIST_UPDATE = "auction" } -- an auction list exists only after a search
local function call(name, ...) -- a dotted name such as C_Item.GetItemInfo is looked up table by table
    local f = _G
    for part in name:gmatch("[^.]+") do f = type(f) == "table" and f[part] or nil end
    return f(...)
end
local function label(prefix, name, ...)
    local parts = {}
    for i = 1, select("#", ...) do local v = select(i, ...); if v ~= nil then parts[#parts + 1] = tostring(v) end end -- a missing argument is not written
    return prefix .. name .. "(" .. table.concat(parts, ",") .. ")"
end
local function recordCall(win, scene, prefix, name, ...)
    local args = { ... }
    return store(label(prefix, name, ...), function() return call(name, unpack(args)) end, nil, win, scene)
end
local function try(name, ...) local r = pack(pcall(call, name, ...)); if r[1] then return unpack(r, 2, r.n) end end -- r.n keeps the values after a nil
local function itemId(i)
    local id = try("GetMerchantItemID", i) -- both clients' own vendor frames read the id this way; a currency row has none
    if type(id) == "number" then return id end
    local link = try("GetMerchantItemLink", i)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end
local function isGear(n) -- any row a weapon (class 2) or armor (class 4); the class comes from the item id and needs no cache
    local instant = C_Item and C_Item.GetItemInfoInstant and "C_Item.GetItemInfoInstant" or "GetItemInfoInstant"
    for i = 1, n do
        local id = itemId(i)
        local classID = id and select(6, try(instant, id))
        if classID == 2 or classID == 4 then return true end
    end
    return false
end
local function recordItem(id)
    if ITEM_FIXTURES[id] then for _, f in ipairs(ITEM_FIXTURES[id]) do store(f[1], f[2], f[3], f[4]) end return end
    local request = C_Item and C_Item.RequestLoadItemDataByID
    if request then pcall(request, id) end
    local list = {}
    for _, name in ipairs({ "GetItemInfo", "C_Item.GetItemInfo" }) do
        local f = { ("%s(%d)"):format(name, id), function() return call(name, id) end, nil, "merchant" }
        list[#list + 1] = f
        store(f[1], f[2], f[3], f[4]) -- an uncached item records nothing now and is replaced when GET_ITEM_INFO_RECEIVED arrives
    end
    ITEM_FIXTURES[id] = list
end
-- The scene this window's opening fills, or nil and the reason. The plain scene takes only its own kind of NPC.
local function sceneFor(win, n)
    local armed = CTProbeDB.armed
    if win == "merchant" then
        local gear = isGear(n)
        if gear then return armed.gear and "gear" or nil, "a gear vendor, and the gear scene is recorded already" end
        return armed.merchant and "merchant" or nil, "a vendor, and the vendor scene is recorded already"
    elseif win == "trainer" then
        local ok, tradeskill = pcall(IsTradeskillTrainer)
        if ok and not tradeskill then return armed.class and "class" or nil, "a class trainer, and the class scene is recorded already" end -- Era answers 1 or nil
        return armed.trainer and "trainer" or nil, "a profession trainer, and the trainer scene is recorded already"
    end
    return armed.auction and "auction" or nil, "the auction scene is recorded already"
end
-- The row indices to record: a trainer's header rows are skipped (type is return 3 on Era, return 2 on Forever) and the real index is kept.
local function rowsFor(win, scene, n)
    local limit, rows = SCENE_ROWS[scene] or ROWS, {}
    for i = 1, n do
        if #rows >= limit then break end
        if win ~= "trainer" then rows[#rows + 1] = i
        else
            local _, a, b = try("GetTrainerServiceInfo", i)
            if a ~= "header" and b ~= "header" then rows[#rows + 1] = i end
        end
    end
    return rows
end
local function complete(rows) -- an auction row is complete when hasAllInfo (return 18) is not false; Blizzard's list hides the others
    for _, i in ipairs(rows) do if select(18, try("GetAuctionItemInfo", "list", i)) == false then return false end end
    return true
end
capture = function(win, e)
    local w = WINDOWS[win]
    local scene = opened[win]
    local free = scene
    for _, s in ipairs(w.scenes) do if CTProbeDB.armed[s] then free = true end end
    if not free then return end
    local countLabel = label("", w.count, w.arg)
    local ok, n = pcall(call, w.count, w.arg) -- read first: the scene decides the label it is stored under
    say(("window %s: %s, count %s"):format(win, e or "update", ok and tostring(n) or "error")) -- every armed event, so the order shows
    if not ok then
        store(countLabel, function() return call(w.count, w.arg) end, nil, win) -- the error entry tells ct.py why the window is missing
        for _, s in ipairs(w.scenes) do CTProbeDB.armed[s] = nil end
        say(("window %s: %s raised an error, so nothing more is recorded"):format(win, w.count))
        return
    end
    if type(n) ~= "number" or n < 1 then
        if win == "trainer" then
            local f = {}
            for _, t in ipairs(FILTERS) do f[#f + 1] = t .. "=" .. tostring((try("GetTrainerServiceTypeFilter", t))) end
            local shown = try("GetTrainerServiceTypeFilter", "available") or try("GetTrainerServiceTypeFilter", "unavailable")
            if shown then say(("window trainer: no rows yet (filter %s); waiting for the next update"):format(table.concat(f, " "))) -- the first event comes before the rows
            else say(("window trainer: no rows (filter %s); tick Available and Unavailable in the trainer's filter"):format(table.concat(f, " "))) end
        else say(("window %s: no rows yet; waiting for the next update"):format(win)) end
        return
    end
    local why
    if not scene then scene, why = sceneFor(win, n) end
    if not scene then say(("window %s: %s"):format(win, why)) return end
    local rows = rowsFor(win, scene, n)
    if win == "trainer" and #rows == 0 then say("window trainer: only header rows; open the categories or tick Unavailable and Used in the filter") return end
    if win == "auction" and not complete(rows) then say("window auction: rows not complete yet; waiting for the next update") return end
    local prefix = scene == w.scenes[#w.scenes] and "" or scene .. ":"
    for l, entry in pairs(CTProbeDB.fixtures) do if entry.scene == scene then CTProbeDB.fixtures[l] = nil end end -- the last update wins
    store(prefix .. countLabel, function() return call(w.count, w.arg) end, nil, win, scene)
    for _, i in ipairs(rows) do
        for _, name in ipairs(w.rows) do
            if w.arg then recordCall(win, scene, prefix, name, w.arg, i) else recordCall(win, scene, prefix, name, i) end -- a nil first argument would end the list
        end
    end
    if w.money then recordCall(win, scene, scene .. ":", "GetMoney") end
    if win == "trainer" then
        recordCall(win, scene, scene .. ":", "IsTradeskillTrainer") -- what told the scene, and the client's 1 or nil
        for _, t in ipairs(FILTERS) do recordCall(win, scene, scene .. ":", "GetTrainerServiceTypeFilter", t) end
    end
    if win == "merchant" then for _, i in ipairs(rows) do local id = itemId(i); if id then recordItem(id) end end end
    CTProbeDB.armed[scene] = nil
    if win ~= "auction" then opened[win] = scene end
    say(("window %s: recorded the count and %d rows as %s"):format(win, #rows, scene))
end
-- An itemKey argument is written as itemKey:<itemID> in the label and stored whole with the call. The results stay until the search changes:
-- the last event of an armed scene wins, and the scene counts as recorded after its first event with rows.
local function argText(v) return type(v) == "table" and ("itemKey:" .. tostring(v.itemID)) or tostring(v) end
captureModern = function(scene, ...)
    if not (CTProbeDB and CTProbeDB.armed and (CTProbeDB.armed[scene] or opened[scene])) then return end
    local first = ...
    if scene ~= "browse" and first == nil then return end
    for l, entry in pairs(CTProbeDB.fixtures) do if entry.scene == scene then CTProbeDB.fixtures[l] = nil end end
    local n = 0
    for _, c in ipairs(MODERN[scene].calls(first)) do
        local name, args, parts, hasTable = c[1], { n = #c - 1 }, {}, false
        for i = 2, #c do args[i - 1] = c[i]; parts[i - 1] = argText(c[i]); if type(c[i]) == "table" then hasTable = true end end
        local e = store(name .. "(" .. table.concat(parts, ",") .. ")", function() return call(name, unpack(args, 1, args.n)) end, nil, "auction", scene, hasTable and args or nil)
        if e.values and e.values[1] and e.values[1].type == "table" then n = n + 1 end
    end
    if n > 0 then CTProbeDB.armed[scene] = nil; opened[scene] = true end
    say(("window auction: %s, %d table results recorded as %s"):format(MODERN[scene].event, n, scene))
end
local function arm(only)
    if not CTProbeDB then say("record arm: saved variables are not loaded yet") return end
    CTProbeDB.fixtures = CTProbeDB.fixtures or {}
    for l, entry in pairs(CTProbeDB.fixtures) do if entry.window then CTProbeDB.fixtures[l] = nil end end -- a new run starts with no old window rows
    CTProbeDB.armed = { merchant = true, gear = true, trainer = true, class = true, auction = true }
    for k in pairs(opened) do opened[k] = nil end -- a window left open from before arming counts as a new opening
    if rawget(_G, "C_AuctionHouse") and C_AuctionHouse.GetBrowseResults then -- Forever's auction house; Era has the list calls instead
        for scene, m in pairs(MODERN) do if windowEvents[m.event] then CTProbeDB.armed[scene] = true end end
    end
    if not windowEvents.AUCTION_ITEM_LIST_UPDATE then
        CTProbeDB.armed.auction = nil
        CTProbeDB.fixtures["GetNumAuctionItems(list)"] = { error = "AUCTION_ITEM_LIST_UPDATE is not an event on this client", window = "auction" }
    end
    if only and only ~= "" then -- /ctp record arm class browse: only the named scenes, so a focused run ends with nothing left
        local want, unknown = {}, {}
        for w in only:gmatch("%S+") do if CTProbeDB.armed[w] then want[w] = true else unknown[#unknown + 1] = w end end
        for s in pairs(CTProbeDB.armed) do if not want[s] then CTProbeDB.armed[s] = nil end end
        if #unknown > 0 then say("record arm: not a scene on this client: " .. table.concat(unknown, ", ")) end
    end
    CTProbeDB.armedList = {}
    for _, s in ipairs({ "gear", "merchant", "class", "trainer", "auction", "browse", "itemsearch", "commodity" }) do
        if CTProbeDB.armed[s] then CTProbeDB.armedList[#CTProbeDB.armedList + 1] = s end
    end
    say("armed: open an armor or weapon vendor and another vendor, a class trainer and a profession trainer, and search the auction house; /ctp record status shows what is left; then /reload. Run /ctp record first")
end
local function status()
    if not (CTProbeDB and CTProbeDB.armed) then say("record status: not armed") return end
    local left, done = {}, {}
    for _, s in ipairs(CTProbeDB.armedList or {}) do -- only what this arm asked for
        if CTProbeDB.armed[s] then left[#left + 1] = s else done[#done + 1] = s end
    end
    say(("record status: recorded %s; still waiting for %s"):format(#done > 0 and table.concat(done, ", ") or "nothing", #left > 0 and table.concat(left, ", ") or "nothing"))
end

-- /ctp record <call> (#214): one call a developer names, such as /ctp record GetItemInfo(6948). The last part of the name must read as a
-- query (Get, Is, Has, Can or Num, or a Unit read, then a capital letter) and not be on ACTS, the query-named calls that act. Each
-- argument is a literal (a number, true, false, nil, quoted text or a bare word read as text): nothing in the command runs as code.
local QUERY = { "Get", "Is", "Has", "Can", "Num", "Unit" }
local ACTS = { GetQuestReward = true } -- takes the quest reward the argument names
local function literal(s)
    s = s:match("^%s*(.-)%s*$")
    local n = s:match("^%-?%d+%.?%d*$") and tonumber(s)
    if n then return true, n end
    if s == "true" then return true, true elseif s == "false" then return true, false elseif s == "nil" then return true, nil end
    local q = s:sub(1, 1)
    if (q == '"' or q == "'") and #s >= 2 and s:sub(-1) == q and not s:sub(2, -2):find(q, 1, true) and not s:find("\\", 1, true) then return true, s:sub(2, -2) end
    if s:match("^[%a_][%w_]*$") then return true, s end
    return false
end
local function splitArgs(text) -- commas inside quotes stay in the argument; nil when a quote is not closed
    local parts, cur, quote = {}, "", nil
    for i = 1, #text do
        local c = text:sub(i, i)
        if quote then cur = cur .. c; if c == quote then quote = nil end
        elseif c == '"' or c == "'" then quote = c; cur = cur .. c
        elseif c == "," then parts[#parts + 1] = cur; cur = ""
        else cur = cur .. c end
    end
    if quote then return nil end
    if #parts > 0 or cur:match("%S") then parts[#parts + 1] = cur end
    return parts
end
local function argText(v)
    if type(v) == "string" then return v:match("^[%a_][%w_]*$") and v or ("%q"):format(v) end
    return tostring(v)
end
-- A personal call: an argument that names a player unit, or a return that is or holds the character's name, realm, GUID or money.
local function personal(args, r)
    for i = 1, args.n do
        local a = args[i]
        if type(a) == "string" and UnitIsPlayer then local ok, p = pcall(UnitIsPlayer, a); if ok and p then return true end end
    end
    local function get(f, ...) if type(f) == "function" then local ok, v = pcall(f, ...); if ok then return v end end end
    local words, money = {}, get(GetMoney)
    for _, w in ipairs({ get(UnitName, "player"), get(GetRealmName), get(GetNormalizedRealmName), get(UnitGUID, "player") }) do
        if type(w) == "string" and w ~= "" then words[#words + 1] = w end
    end
    local function holds(v, depth)
        if type(v) == "string" then for _, w in ipairs(words) do if v:find(w, 1, true) then return true end end
        elseif type(v) == "number" then return money ~= nil and v == money
        elseif type(v) == "table" and depth < 4 then for k, x in pairs(v) do if holds(k, depth + 1) or holds(x, depth + 1) then return true end end end
        return false
    end
    for i = 2, r.n do if holds(r[i], 1) then return true end end
    return false
end
local function recordOne(text)
    if not CTProbeDB then say("record: saved variables are not loaded yet") return end
    local name, inner = text:match("^%s*([%a_][%w_%.]*)%s*%((.*)%)%s*$")
    if not name then say("record: write one call, such as /ctp record GetItemInfo(6948)") return end
    local last, query = name:match("([^.]+)$"), false
    for _, p in ipairs(QUERY) do if last:match("^" .. p .. "%u") then query = true end end
    if not query or ACTS[last] then say(("record: %s is not a read-only call; the name must start with Get, Is, Has, Can, Num or Unit"):format(name)) return end
    local parts = splitArgs(inner)
    if not parts then say("record: a quote is not closed") return end
    local args, shown = { n = #parts }, {}
    for i, p in ipairs(parts) do
        local ok, v = literal(p)
        if not ok then say(("record: argument %d (%s) is not a number, true, false, nil or text"):format(i, p)) return end
        args[i], shown[i] = v, argText(v)
    end
    CTProbeDB.fixtures = CTProbeDB.fixtures or {}
    if not CTProbeDB.fixtures["GetBuildInfo()"] then store("GetBuildInfo()", function() return GetBuildInfo() end) end -- ct.py reads the client from it
    local label = name .. "(" .. table.concat(shown, ", ") .. ")"
    local r = pack(pcall(call, name, unpack(args, 1, args.n)))
    local typeOnly = r[1] and personal(args, r) or nil
    local entry = store(label, function() if not r[1] then error(r[2], 0) end; return unpack(r, 2, r.n) end, typeOnly, nil, nil, args)
    entry.picked = true
    if entry.error then say(("record: %s raised an error: %s"):format(label, entry.error))
    else say(("record: %s recorded, %d values%s; /reload to save it"):format(label, entry.n, typeOnly and ", by type only (it holds a personal value)" or "")) end
end

SLASH_CTPROBE1 = "/ctp"
SlashCmdList.CTPROBE = function(msg)
    if msg == "build" then build()
    elseif msg == "clear" then if log then wipe(log) end; say("cleared")
    elseif msg == "now" then probe()
    elseif msg == "tooltip" then tooltip()
    elseif msg == "record arm" or msg:match("^record arm ") then arm(msg:match("^record arm%s+(.+)$"))
    elseif msg == "record status" then status()
    elseif msg == "record" then record()
    elseif msg:match("^record%s+[%a_][%w_%.]*%s*%(") then recordOne(msg:match("^record%s+(.+)$"))
    elseif msg:match("^budget") then budget(msg:match("^budget%s*(%S*)"))
    elseif msg == "life" then
        for _, l in ipairs(log or early) do if l:find("life", 1, true) then print(l) end end -- the whole log, all sessions
    elseif msg:match("^taint") then taint(msg:match("^taint%s*(%S*)"))
    else say("button=" .. tostring(b and b:IsShown()) .. "; /ctp now, taint, tooltip, budget, record, record <call>, record arm, life, clear") end
end
