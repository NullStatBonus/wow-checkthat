-- Fixture addon for the offline entry runner. It does what real addons do: capture a game function in a
-- file-scope local, look another one up when called, handle an event and register entry points.
local addonName = ...
local GetItemInfo = GetItemInfo -- captured at load, as in "local GetItemInfo = GetItemInfo"

local state = { events = 0, last = nil }
MockAddonRan = true -- lets a test see that no addon file ran

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", function(_, event) state.events = state.events + 1; state.last = event end)

if CheckThat and CheckThat.Entry then
    CheckThat.Entry(addonName, "captured_name", function(id) return (GetItemInfo(id)) end)
    CheckThat.Entry(addonName, "live_name", function(id) return (_G.GetItemInfo(id)) end)
    CheckThat.Entry(addonName, "add", function(a, b) return a + b end)
    CheckThat.Entry(addonName, "boom", function() error("boom: bad input", 0) end)
    CheckThat.Entry(addonName, "events_seen", function() return state.events, state.last end)
    -- Libraries loaded through embeds.xml before this file: their state, and whether the commented-out one ran.
    CheckThat.Entry(addonName, "libs", function() local l = MockLibs or {}; return l.one, l.two == true, l.skipped == true end)
end
