-- Fixture: entries that call game functions a plan mocks from a recording. Not shipped.
local addonName = ...
CheckThat.Entry(addonName, "info_count", function(id) return select("#", C_Item.GetItemInfo(id)) end)
CheckThat.Entry(addonName, "info_first", function(id) return (C_Item.GetItemInfo(id)) end)
CheckThat.Entry(addonName, "info_type", function(id, n) return type((select(n, C_Item.GetItemInfo(id)))) end)
CheckThat.Entry(addonName, "info_old", function(id) return (GetItemInfo(id)) end)
