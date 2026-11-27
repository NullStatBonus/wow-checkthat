-- Fixture: entries that call game functions a plan mocks from a recording. Not shipped.
local addonName = ...
CheckThat.Entry(addonName, "info_count", function(id) return select("#", C_Item.GetItemInfo(id)) end)
CheckThat.Entry(addonName, "info_first", function(id) return (C_Item.GetItemInfo(id)) end)
CheckThat.Entry(addonName, "info_type", function(id, n) return type((select(n, C_Item.GetItemInfo(id)))) end)
CheckThat.Entry(addonName, "info_old", function(id) return (GetItemInfo(id)) end)
CheckThat.Entry(addonName, "trainer_row", function(i) local name, a, b = GetTrainerServiceInfo(i); return name, tostring(a), b end) -- the window calls a plan mocks from a scene recording
CheckThat.Entry(addonName, "trainer_cost", function(i) return (GetTrainerServiceCost(i)) end)
CheckThat.Entry(addonName, "auction_link", function(i) return (GetAuctionItemLink("list", i)) end)
CheckThat.Entry(addonName, "vendor_price", function(i) return (select(3, GetMerchantItemInfo(i))) end)
