-- Adapter reads that guard protected frames: a missing or failing game function never reads as "safe".
local ns, test, T, finish, H = dofile("tests/harness.lua")()
H.plain(ns)
local A = ns.Adapter

test("InCombat reads as in combat when the game cannot say", function()
    local saved = _G.InCombatLockdown
    _G.InCombatLockdown = nil
    T.eq(A.InCombat(), true, "function missing")
    _G.InCombatLockdown = function() error("broken") end
    T.eq(A.InCombat(), true, "function raises")
    _G.InCombatLockdown = function() return nil end
    T.eq(A.InCombat(), false, "the game's own answer on older clients")
    _G.InCombatLockdown = function() return 1 end
    T.eq(A.InCombat(), true)
    _G.InCombatLockdown = saved
end)

test("Confirm closes an open dialog of the same key, so the new text shows", function()
    local hidden, shown = {}, {}
    local d, h, s = _G.StaticPopupDialogs, _G.StaticPopup_Hide, _G.StaticPopup_Show
    _G.StaticPopupDialogs = {}
    _G.StaticPopup_Hide = function(k) hidden[#hidden + 1] = k end
    _G.StaticPopup_Show = function(k) shown[#shown + 1] = k end
    T.ok(A.Confirm("first", function() end))
    T.ok(A.Confirm("second", function() end))
    T.eq(#hidden, 2, "each call closes an earlier dialog first")
    T.eq(_G.StaticPopupDialogs["WOWCHECKTHAT_CONFIRM"].text, "second")
    _G.StaticPopupDialogs, _G.StaticPopup_Hide, _G.StaticPopup_Show = d, h, s
end)
-- Reads every member of a table global through the step reads, the way the census does.
local function walkTable(name)
    local h, isFrame, filtered = A.CensusOpen(name)
    if not h then return nil, isFrame end
    local members, unknown, cursor = {}, false, nil
    while true do
        local ok, k, ty, keep, unk = A.CensusMember(h, cursor)
        if not ok or k == nil then break end
        cursor = k
        if unk then unknown = true end
        if keep then members[k] = ty end
    end
    return members, isFrame, filtered and not unknown
end
test("SlashOwner names the addon that wrote the SLASH_ global, the game for a secure one, and nil when unknown (#244)", function()
    H.stub(_G, "SlashCmdList", { MYADDON = function() end, HELP = function() end, OTHER = function() end })
    H.stub(_G, "SLASH_MYADDON1", "/my"); H.stub(_G, "SLASH_MYADDON2", "/MyAddon")
    H.stub(_G, "SLASH_HELP1", "/help"); H.stub(_G, "SLASH_OTHER1", "/oth")
    local owners = { SLASH_MYADDON1 = "MyAddon", SLASH_MYADDON2 = "MyAddon", SLASH_OTHER1 = "OtherAddon" }
    H.stub(_G, "issecurevariable", function(name) if owners[name] then return false, owners[name] end return true end)
    T.eq(A.SlashOwner("/my"), "MyAddon"); T.eq(A.SlashOwner("/myaddon"), "MyAddon", "any case")
    T.eq(A.SlashOwner("/help"), "game"); T.eq(A.SlashOwner("/oth"), "OtherAddon")
    T.eq(A.SlashOwner("/none"), nil, "not registered")
    T.eq(select(2, A.SlashOwner("/my")), "SLASH_MYADDON1 by MyAddon", "the debug log says how")
    T.eq(select(2, A.SlashOwner("/help")), "SLASH_HELP1 secure")
    T.eq(select(2, A.SlashOwner("/none")), "no SLASH_ global holds it (3 keys)")
    H.stub(_G, "issecurevariable", nil)
    T.eq(A.SlashOwner("/my"), nil, "a client that cannot say")
    T.eq(select(2, A.SlashOwner("/my")), "no issecurevariable")
end)

test("census reads use rawget and next, skip frames, and fail to nil", function()
    _G.CensusProbe = setmetatable({ Alpha = function() end, [1] = true }, { __index = function() error("an __index ran") end })
    T.eq(A.CensusType("CensusProbe"), "table"); T.eq(A.CensusType("CensusNoSuchName"), nil)
    local found
    local cursor = nil
    while true do
        local ok, k = A.CensusNextKey(cursor)
        T.ok(ok, "next works"); if k == nil then break end
        cursor = k
        if k == "CensusProbe" then found = true end
    end
    T.ok(found, "CensusNextKey steps through the keys")
    T.eq(select(1, A.CensusNextKey("CensusNoSuchKeyAnywhere")), false, "a key that is gone fails, not a nil end")
    local members, isFrame = walkTable("CensusProbe")
    T.eq(isFrame, false); T.eq(members.Alpha, "function"); T.eq(members[1], "boolean")
    _G.CensusFrame = setmetatable({ [0] = newproxy() }, { __index = function() error("an __index ran") end })
    local m, frame = walkTable("CensusFrame")
    T.eq(m, nil); T.eq(frame, true)
    _G.CensusFake = setmetatable({ GetObjectType = function() end }, { __index = function() error("an __index ran") end })
    T.eq(select(2, walkTable("CensusFake")), false, "a table with a GetObjectType member and no [0] userdata is no frame")
    _G.CensusFake = nil
    T.eq(walkTable("CensusNoSuchName"), nil)
    _G.CensusProbe, _G.CensusFrame = nil, nil
end)

test("census skips what an addon defined when issecurevariable can tell, and cuts a huge table", function()
    local isv = _G.issecurevariable
    local g = { CensusMine = true }
    _G.CensusMine, _G.CensusBlizz = {}, {}
    _G.issecurevariable = function(a, b)
        if b == nil then return not (a == "CensusMine"), nil end
        if type(a) ~= "table" then error("bad table") end
        return b ~= "Added"
    end
    local ty, secure = A.CensusType("CensusMine"); T.eq(ty, "table"); T.eq(secure, false)
    ty, secure = A.CensusType("CensusBlizz"); T.eq(secure, true)
    _G.CensusBlizz = { Own = 1, Added = 2 }
    local members, frame, filtered = walkTable("CensusBlizz")
    T.eq(members.Own, "number"); T.eq(members.Added, nil, "an added member is left out"); T.eq(filtered, true)
    _G.issecurevariable = function() error("no table form") end
    ty, secure = A.CensusType("CensusBlizz"); T.eq(ty, "table"); T.eq(secure, nil, "unknown, not true")
    members, frame, filtered = walkTable("CensusBlizz")
    T.eq(members.Added, "number"); T.eq(filtered, false)
    _G.issecurevariable = nil
    T.eq(select(2, A.CensusType("CensusBlizz")), nil)
    _G.CensusMine, _G.CensusBlizz, _G.issecurevariable = nil, nil, isv
end)

test("a member check that works on a probe and fails on the real table reports unfiltered", function()
    local isv = _G.issecurevariable
    _G.CensusOdd = { One = 1, Two = 2 }
    local real
    _G.issecurevariable = function(a, b)
        if a == real then error("refuses this table") end
        return true
    end
    real = _G.CensusOdd
    local members, _, filtered = walkTable("CensusOdd")
    T.eq(members.One, "number", "the member is kept")
    T.eq(filtered, false, "but the table is unfiltered")
    local h, _, f = A.CensusOpen("CensusOdd")
    T.eq(f, true, "the probe was accepted")
    local ok, k, _, keep, unknown = A.CensusMember(h, nil)
    T.ok(ok and keep and unknown, "an unknown answer on a real key")
    _G.CensusOdd, _G.issecurevariable = nil, isv
end)

test("After reports whether it scheduled", function()
    local ct = _G.C_Timer
    _G.C_Timer = nil
    T.eq(A.After(0, function() end), false)
    local ran
    _G.C_Timer = { After = function(_, fn) ran = fn end }
    T.eq(A.After(0, function() end), true); T.ok(ran)
    _G.C_Timer = { After = function() error("refused") end }
    T.eq(A.After(0, function() end), false)
    _G.C_Timer = ct
end)

test("census widget methods come from the metatable, and a refused type is nil", function()
    local cf, up = _G.CreateFrame, _G.UIParent
    _G.UIParent = {}
    local methods = { SetPoint = function() end, Hide = function() end, Data = 1 }
    _G.CreateFrame = function(kind)
        if kind == "Nope" then error("unknown frame type") end
        return setmetatable({}, { __index = methods })
    end
    local list = A.CensusWidget("Slider")
    table.sort(list)
    T.eq(table.concat(list, ","), "Hide,SetPoint", "functions only")
    T.eq(A.CensusWidget("Nope"), nil)
    _G.CreateFrame, _G.UIParent = cf, up
end)

test("census clock and addon list are nil when the client has none", function()
    local dp, g1, g2 = _G.debugprofilestop, _G.GetNumAddOns, _G.C_AddOns
    _G.debugprofilestop, _G.GetNumAddOns, _G.C_AddOns = nil, nil, nil
    T.eq(A.Clock(), nil); T.eq(A.LoadedAddons(), nil)
    _G.debugprofilestop = function() return 5 end
    T.eq(A.Clock(), 5)
    _G.C_AddOns = { GetNumAddOns = function() return 2 end, GetAddOnInfo = function(i) return i == 1 and { name = "B" } or "A" end, IsAddOnLoaded = function() return true end }
    T.eq(table.concat(A.LoadedAddons(), ","), "A,B", "string or table answers, sorted")
    _G.debugprofilestop, _G.GetNumAddOns, _G.C_AddOns = dp, g1, g2
end)

finish()
