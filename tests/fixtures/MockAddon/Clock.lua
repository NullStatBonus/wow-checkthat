-- Fixture addon for offline level 4. Not shipped.
local addonName = ...
local fired, ticks, order = nil, 0, {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("BAG_UPDATE")
frame:SetScript("OnEvent", function(_, event, bag) order[#order + 1] = event .. " " .. tostring(bag) end)

CheckThat.Entry(addonName, "after", function(s) C_Timer.After(s, function() fired = GetTime() end); return true end)
CheckThat.Entry(addonName, "fired", function() return fired or "no" end)
CheckThat.Entry(addonName, "now", function() return GetTime(), time() end)
CheckThat.Entry(addonName, "ticker", function(s, n) C_Timer.NewTicker(s, function() ticks = ticks + 1 end, n); return true end)
CheckThat.Entry(addonName, "ticks", function() return ticks end)
CheckThat.Entry(addonName, "cancelled_timer", function(s)
    local t = C_Timer.NewTimer(s, function() fired = "cancelled timer ran" end)
    t:Cancel()
    return t:IsCancelled()
end)
CheckThat.Entry(addonName, "order", function()
    C_Timer.After(2, function() order[#order + 1] = "b" end)
    C_Timer.After(1, function() order[#order + 1] = "a"; C_Timer.After(0.5, function() order[#order + 1] = "a2" end) end)
    C_Timer.After(2, function() order[#order + 1] = "c" end)
    return true
end)
CheckThat.Entry(addonName, "seen", function() return table.concat(order, ",") end)
CheckThat.Entry(addonName, "boom_later", function() C_Timer.After(1, function() error("late boom", 0) end); return true end)
CheckThat.Entry(addonName, "register", function(ev) local ok, err = pcall(frame.RegisterEvent, frame, ev); if ok then return true end; return false, err end)
