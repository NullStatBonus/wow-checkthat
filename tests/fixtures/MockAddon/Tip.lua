-- Fixture: BAG_UPDATE fills GameTooltip. Not shipped.
local frame = CreateFrame("Frame")
frame:RegisterEvent("BAG_UPDATE")
frame:SetScript("OnEvent", function()
    GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
    GameTooltip:SetText("Title")
    GameTooltip:AddLine("Sell price: 5")
    GameTooltip:AddDoubleLine("Left", "Right")
end)
