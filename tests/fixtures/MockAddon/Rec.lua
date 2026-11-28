-- Fixture: entries that call game functions a plan mocks from a recording. Not shipped.
local addonName = ...
CheckThat.Entry(addonName, "info_count", function(id) return select("#", C_Item.GetItemInfo(id)) end)
CheckThat.Entry(addonName, "info_first", function(id) return (C_Item.GetItemInfo(id)) end)
CheckThat.Entry(addonName, "info_type", function(id, n) return type((select(n, C_Item.GetItemInfo(id)))) end)
CheckThat.Entry(addonName, "info_old", function(id) return (GetItemInfo(id)) end)
CheckThat.Entry(addonName, "trainer_row", function(i) local name, a, b = GetTrainerServiceInfo(i); return name, tostring(a), b end) -- the window calls a plan mocks from a scene recording
CheckThat.Entry(addonName, "trainer_cost", function(i) return (GetTrainerServiceCost(i)) end)
CheckThat.Entry(addonName, "auction_link", function(i) return (GetAuctionItemLink("list", i)) end)
CheckThat.Entry(addonName, "vendor_info", function(i) local info = C_MerchantFrame.GetItemInfo(i); local name, price = info.name, info.price; info.name = "changed by the addon"; return name, price, info.stackCount end)
CheckThat.Entry(addonName, "commodity_price", function(id, i) local r = C_AuctionHouse.GetCommoditySearchResultInfo(id, i); return r and r.unitPrice, r and #r.owners end)
CheckThat.Entry(addonName, "item_result", function(key, i) local r = C_AuctionHouse.GetItemSearchResultInfo(key, i); if r then return r.buyoutAmount, r.itemKey.itemID end end)
CheckThat.Entry(addonName, "browse_count", function() return #C_AuctionHouse.GetBrowseResults() end)
CheckThat.Entry(addonName, "spell_name", function(id) return (GetSpellInfo(id)) end) -- a call the closed mock list does not name (#214)
CheckThat.Entry(addonName, "unit_level", function(unit) return (UnitLevel(unit)) end)
CheckThat.Entry(addonName, "vendor_price", function(i) return (select(3, GetMerchantItemInfo(i))) end)
