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
finish()
