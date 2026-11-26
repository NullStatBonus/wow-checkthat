-- Fixture: entries that replace, restore and hook a game global, and read issecurevariable. Not shipped.
local addonName = ...
local original = GetMoney
CheckThat.Entry(addonName, "replace", function() GetMoney = function() return 1 end end)
CheckThat.Entry(addonName, "restore", function() GetMoney = original end)
CheckThat.Entry(addonName, "replace_and_restore", function() GetMoney = function() return 1 end; GetMoney = original end)
CheckThat.Entry(addonName, "hook", function() hooksecurefunc("GetMoney", function() end) end)
CheckThat.Entry(addonName, "secure", function(name) return (issecurevariable(name)) end)
