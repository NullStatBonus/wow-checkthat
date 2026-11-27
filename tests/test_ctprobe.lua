-- The in-game probe (tools/ctprobe) run in the fake client: every /ctp command must run without an error and write the lines the
-- measurements are read from. It proves the probe works, not what the game answers.
local loadfile = loadfile
local ns, test, T, finish, H = dofile("tests/harness.lua")()
local L51 = dofile("tools/lua51_check.lua")
local PATH = "tools/ctprobe/CTProbe/CTProbe.lua"

local function probe(opts)
    local restore = H.snapshot()
    T.finally(restore)
    opts.client = opts.client or "era"
    opts.clock = {}
    local st = H.stubClient(opts)
    local create = _G.CreateFrame -- the shared fake client keeps no record of registered events: the runner adds one the same way
    _G.CreateFrame = function(...)
        local f = create(...)
        f.events = {}
        rawset(f, "RegisterEvent", function(self, ev) self.events[ev] = true end)
        return f
    end
    _G.CTProbeDB = nil
    assert(loadfile(PATH))("CTProbe", {})
    local frame
    for _, f in ipairs(st.frames) do if rawget(f, "scripts") and f.scripts.OnEvent and rawget(f, "events") then frame = f end end
    local function fire(e, ...) frame.scripts.OnEvent(frame, e, ...) end
    fire("ADDON_LOADED", "CTProbe")
    return st, fire
end
local function has(pattern) for _, l in ipairs(CTProbeDB.log) do if l:find(pattern, 1, true) then return l end end end

test("the probe file is Lua 5.1", function()
    T.same(L51.check(PATH), {}, "Lua 5.1 findings")
end)

test("the lifecycle events are logged in order with their arguments and IsLoggedIn, and the file-scope line is kept", function()
    local st, fire = probe({})
    fire("VARIABLES_LOADED"); fire("PLAYER_LOGIN"); fire("PLAYER_ENTERING_WORLD", true, false)
    fire("PLAYER_LEAVING_WORLD"); fire("PLAYER_LOGOUT"); fire("ADDONS_UNLOADING", false)
    fire("ADDON_LOADED", "SomeOtherAddon")
    T.ok(has("life file scope: CTProbeDB is nil"), "the line made before ADDON_LOADED reaches the log")
    T.ok(not has("SomeOtherAddon"), "another addon's load is not logged")
    local order = {}
    for _, l in ipairs(CTProbeDB.log) do local n, e, a = l:match("life #(%d+) (%u[%u_]*)%(([^)]*)%)"); if n then order[#order + 1] = e .. "(" .. a .. ")" end end
    T.same(order, { "ADDON_LOADED(CTProbe)", "VARIABLES_LOADED()", "PLAYER_LOGIN()", "PLAYER_ENTERING_WORLD(true,false)", "PLAYER_LEAVING_WORLD()", "PLAYER_LOGOUT()", "ADDONS_UNLOADING(false)" })
    T.ok(has("IsLoggedIn="), "IsLoggedIn is logged with each event")
    SlashCmdList.CTPROBE("life")
    T.ok(#st.said > 0, "/ctp life prints")
end)

test("/ctp record stores the read-only calls, and personal values by type only", function()
    probe({})
    _G.GetItemInfo = function() return nil, "second" end -- an uncached item: a nil before a value
    _G.GetMoney = function() return 12345 end
    _G.UnitName = function() return "Secretname" end
    SlashCmdList.CTPROBE("record")
    local fx = CTProbeDB.fixtures
    T.ok(fx["GetBuildInfo()"] and fx["GetBuildInfo()"].n >= 2, "GetBuildInfo returns several values")
    T.eq(fx["GetBuildInfo()"].values[1].type, "string")
    T.eq(fx["GetMoney()"].typeOnly, true); T.eq(fx["GetMoney()"].values[1].type, "number"); T.eq(fx["GetMoney()"].values[1].value, nil, "money is recorded by type only")
    T.eq(fx["UnitName(player)"].typeOnly, true); T.eq(fx["UnitName(player)"].values[1].value, nil, "a character name is never recorded")
    T.eq(fx["GetItemInfo(6948)"].n, 2, "a nil first value is counted"); T.eq(fx["GetItemInfo(6948)"].values[1].type, "nil"); T.eq(fx["GetItemInfo(6948)"].values[2].value, "second")
    T.ok(has("record:") and has("calls recorded"), "the summary line")
    T.ok(CTProbeDB.fixturesBuild:find("%d+%.%d+%.%d+"), CTProbeDB.fixturesBuild)
end)

test("/ctp tooltip logs the state after each step and what fired", function()
    local st = probe({})
    SlashCmdList.CTPROBE("tooltip")
    T.ok(has("tooltip: before SetOwner: IsShown=false"), "the tooltip starts hidden")
    T.ok(has("after SetText: IsShown="), "the state after SetText"); T.ok(has("NumLines=2"), "a title and a line")
    T.ok(has("SetHyperlink item:6948 ok="), "the hyperlink call is logged"); T.ok(has("hooks fired at once"), "the hook counters")
    st.advance(1)
    T.ok(has("0.5 s later"), "the delayed reading")
end)

test("/ctp budget runs its stages in separate timers, stops at the cap and reports the rates", function()
    local st = probe({})
    CTProbeDB.budgetCapMs = 5 -- a stage is allowed 5 ms, so the doubling stops after a few stages and the test stays quick
    SlashCmdList.CTPROBE("budget")
    T.ok(has("budget: start"))
    for _ = 1, 60 do st.advance(1); if has("budget: done") then break end end
    T.ok(has("budget: starting loop n=100000"), "a line is written before each stage, so an aborted stage shows")
    T.ok(has("budget: loop n=100000 ok=true"), "the first stage of the loop family")
    T.ok(has("budget: calls n=100000 ok=true"), "the first stage of the calls family")
    T.ok(has("stops at n="), "a family stops when the next stage would pass the cap")
    T.ok(has("budget: done. loop "), "the summary with the rates")
end)

test("/ctp taint hook measures hooksecurefunc, and a throwing hook leaves the original's result", function()
    local st = probe({ taint = true })
    SlashCmdList.CTPROBE("taint hook")
    T.ok(has("UnitName before hooking: secure=true"), "before"); T.ok(has("hooksecurefunc ok=true"))
    T.ok(has("UnitName after hooking: secure=true"), "the harness leaves a hooked name secure: " .. tostring(has("after hooking")))
    T.ok(has("the hook ran=true with the arguments (player)"), tostring(has("the hook ran")))
    rawset(_G, "geterrorhandler", function() return function() end end)
    SlashCmdList.CTPROBE("taint hookerror")
    T.ok(has("GetTime() ok=true returned a number"), tostring(has("after a throwing hook")))
    local handled = 0
    rawset(_G, "geterrorhandler", function() return function() handled = handled + 1 end end)
    SlashCmdList.CTPROBE("record"); SlashCmdList.CTPROBE("taint run")
    T.eq(handled, 0, "the hook raised once, for the probe's own call, and not for the log lines after it")
end)

test("/ctp taint run still measures the replaced global, and the other commands do not raise", function()
    probe({ taint = true })
    SlashCmdList.CTPROBE("taint run")
    T.ok(has("GetMoney after replacing: secure=false"), "a replaced game global reads insecure when the harness models taint")
    T.ok(has("GetMoney after restoring the original: secure=false"), "and stays so")
    SlashCmdList.CTPROBE(""); SlashCmdList.CTPROBE("clear")
end)

-- Armed window capture: the calls return nothing unless the window is open, so the probe records them on the window's event.
local function vendorFakes(rows)
    _G.GetMerchantNumItems = function() return rows end
    _G.GetMerchantItemInfo = function(i) return "Item" .. i, 130000 + i, 250 * i, 1, -1, true, true end
    _G.GetMerchantItemLink = function(i) return "|cffffffff|Hitem:" .. i .. ":::::::::::::::::|h[Item" .. i .. "]|h|r" end
end

test("armed: a vendor window records its count and first rows once, tagged with the window", function()
    local _, fire = probe({})
    vendorFakes(5)
    fire("MERCHANT_SHOW")
    T.eq(CTProbeDB.fixtures, nil, "nothing is recorded before the probe is armed")
    SlashCmdList.CTPROBE("record arm")
    fire("MERCHANT_SHOW")
    local fx = CTProbeDB.fixtures
    T.eq(fx["GetMerchantNumItems()"].values[1].value, 5)
    T.eq(fx["GetMerchantNumItems()"].window, "merchant")
    T.eq(fx["GetMerchantItemInfo(1)"].values[1].value, "Item1"); T.eq(fx["GetMerchantItemInfo(3)"].values[3].value, 750)
    T.eq(fx["GetMerchantItemInfo(3)"].window, "merchant")
    T.ok(fx["GetMerchantItemLink(2)"].values[1].value:find("item:2:", 1, true), "the link is recorded")
    T.eq(fx["GetMerchantItemInfo(4)"], nil, "only the first three rows")
    T.ok(has("window merchant: recorded"), "the log says what was recorded")
    _G.GetMerchantItemInfo = function() return "Changed" end
    fire("MERCHANT_SHOW"); fire("MERCHANT_UPDATE") -- the window is disarmed after one capture
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(1)"].values[1].value, "Item1", "a second window opening records nothing more")
end)

test("armed: a vendor window with no rows yet is tried again on the next update", function()
    local _, fire = probe({})
    vendorFakes(0)
    SlashCmdList.CTPROBE("record arm")
    fire("MERCHANT_SHOW")
    T.eq(CTProbeDB.fixtures["GetMerchantNumItems()"].values[1].value, 0)
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(1)"], nil, "no row is recorded for an empty list")
    T.ok(has("window merchant: no rows yet"), "the log says so")
    vendorFakes(2)
    fire("MERCHANT_UPDATE")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(2)"].values[1].value, "Item2")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(3)"], nil, "a list of two has two rows")
end)

test("armed: trainer and auction windows record their own calls, and a missing function is an error entry", function()
    local _, fire = probe({})
    _G.IsTradeskillTrainer = function() return 1 end -- a profession trainer (Era answers 1 or nil)
    _G.GetNumTrainerServices = function() return 4 end
    _G.GetTrainerServiceInfo = function(i) return "Spell" .. i, "Rank 1", "available", true end
    _G.GetTrainerServiceCost = function(i) return 100 * i, false end
    _G.GetTrainerServiceSkillReq = function() return nil end
    _G.GetNumAuctionItems = function(kind) return kind == "list" and 2 or 0, 40 end
    _G.GetAuctionItemInfo = function(kind, i) return "Ore" .. i, 1, 20, 1, true, 10, "", 100, 5, 500, 0, false, "", "Seller", "", 0, 2770 + i, true end
    SlashCmdList.CTPROBE("record arm")
    fire("TRAINER_SHOW"); fire("AUCTION_ITEM_LIST_UPDATE")
    local fx = CTProbeDB.fixtures
    T.eq(fx["GetNumTrainerServices()"].window, "trainer")
    T.eq(fx["GetTrainerServiceInfo(2)"].values[2].value, "Rank 1")
    T.eq(fx["GetTrainerServiceCost(3)"].values[1].value, 300)
    T.eq(fx["GetTrainerServiceSkillReq(1)"].values[1].type, "nil", "a nil return is kept")
    T.eq(fx["GetNumAuctionItems(list)"].values[1].value, 2, "a string argument is written as a plain word in the label")
    T.eq(fx["GetAuctionItemInfo(list,2)"].values[1].value, "Ore2"); T.eq(fx["GetAuctionItemInfo(list,2)"].window, "auction")
    T.eq(fx["GetAuctionItemInfo(list,3)"], nil, "two results, two rows")
    _G.GetNumTrainerServices = nil
    SlashCmdList.CTPROBE("record arm"); fire("TRAINER_SHOW")
    T.ok(CTProbeDB.fixtures["GetNumTrainerServices()"].error, "a function the client lacks is recorded as an error, so ct.py can say why it is skipped")
    T.eq(CTProbeDB.armed.trainer, nil, "and the window is disarmed, because nothing will change")
    T.ok(has("raised an error, so nothing more is recorded"), "the log says so")
end)

test("armed: nothing is recorded for a window that was not armed, and /ctp record keeps window captures", function()
    local _, fire = probe({})
    vendorFakes(2)
    fire("TRAINER_SHOW")
    T.eq(CTProbeDB.fixtures, nil, "a window that is not armed records nothing")
    SlashCmdList.CTPROBE("record arm")
    CTProbeDB.armed.trainer = nil
    fire("TRAINER_SHOW")
    T.eq(CTProbeDB.fixtures["GetNumTrainerServices()"], nil, "a window that was disarmed records nothing")
    fire("MERCHANT_SHOW")
    SlashCmdList.CTPROBE("record")
    T.ok(CTProbeDB.fixtures["GetMerchantNumItems()"], "a second /ctp record keeps what the windows recorded")
    T.ok(CTProbeDB.fixtures["GetBuildInfo()"], "and records its own list")
end)

test("armed capture calls nothing that changes state", function()
    local _, fire = probe({})
    local f = assert(io.open(PATH)); local src = f:read("*a"); f:close()
    for _, name in ipairs({ "BuyMerchantItem", "PickupMerchantItem", "BuyTrainerService", "PlaceAuctionBid", "StartAuction", "CloseMerchant" }) do
        T.ok(not src:find(name, 1, true), name .. " is not in the probe")
    end
    local called = {}
    for _, name in ipairs({ "BuyMerchantItem", "PickupMerchantItem", "BuyTrainerService", "PlaceAuctionBid", "StartAuction", "CloseMerchant" }) do
        _G[name] = function() called[#called + 1] = name end
    end
    vendorFakes(3)
    SlashCmdList.CTPROBE("record arm")
    fire("MERCHANT_SHOW"); fire("TRAINER_SHOW"); fire("AUCTION_ITEM_LIST_UPDATE")
    T.same(called, {})
end)

test("/ctp record asks for the candidate armor and weapon and records them when the client delivers them", function()
    local _, fire = probe({})
    local asked, cached = {}, {}
    _G.C_Item = _G.C_Item or {}
    _G.C_Item.RequestLoadItemDataByID = function(id) asked[#asked + 1] = id end
    _G.GetItemInfo = function(id) if cached[id] then return "Name" .. id, "|Hitem:" .. id .. "|h", 3, 60, 55, "Armor", "Plate", 1, "INVTYPE_HEAD", 1, 4321 end end
    SlashCmdList.CTPROBE("record")
    T.same(asked, { 12640, 12784 }, "both candidates are requested")
    T.eq(CTProbeDB.fixtures["GetItemInfo(12640)"].n, 0, "an uncached item records no value")
    cached[12640] = true
    fire("GET_ITEM_INFO_RECEIVED", 12640, true)
    T.eq(CTProbeDB.fixtures["GetItemInfo(12640)"].values[1].value, "Name12640", "the delivery replaces the empty record")
    T.eq(CTProbeDB.fixtures["GetItemInfo(12640)"].values[11].value, 4321, "with the sell price")
    T.ok(has("item 12640 delivered"), "the log says so")
    fire("GET_ITEM_INFO_RECEIVED", 6948, true)
    T.eq(CTProbeDB.fixtures["GetItemInfo(12784)"].n, 0, "an item that has not arrived stays empty")
end)

test("armed: a gear vendor and a plain vendor each fill their own scene, with money and the rows' item info", function()
    local _, fire = probe({})
    vendorFakes(4)
    _G.GetMoney = function() return 98765 end
    local gearIds = {}
    _G.C_Item = _G.C_Item or {}
    _G.C_Item.GetItemInfoInstant = function(id) return id, "Armor", "Plate", "INVTYPE_HEAD", 1, gearIds[id] and 4 or 0, 0 end
    _G.GetItemInfo = function(id) return "Info" .. id end
    _G.C_Item.GetItemInfo = function(id) return "CInfo" .. id end
    SlashCmdList.CTPROBE("record arm")
    gearIds[2] = true
    fire("MERCHANT_SHOW")
    local fx = CTProbeDB.fixtures
    T.eq(fx["gear:GetMerchantNumItems()"].values[1].value, 4, "a vendor with armor fills the gear scene")
    T.eq(fx["gear:GetMerchantItemInfo(2)"].values[1].value, "Item2"); T.eq(fx["gear:GetMerchantItemInfo(2)"].window, "merchant")
    T.eq(fx["GetMerchantItemInfo(1)"], nil, "the plain labels are left for a plain vendor")
    T.eq(fx["gear:GetMoney()"].values[1].value, 98765, "money is recorded with its value beside the vendor")
    T.eq(fx["gear:GetMoney()"].typeOnly, nil)
    T.eq(fx["GetItemInfo(2)"].values[1].value, "Info2"); T.eq(fx["GetItemInfo(2)"].window, "merchant", "the row's item info is tagged with the window")
    T.eq(fx["C_Item.GetItemInfo(3)"].values[1].value, "CInfo3")
    T.ok(has("recorded the count and 3 rows as gear"), "the log names the scene")
    gearIds = {}
    vendorFakes(2)
    fire("MERCHANT_SHOW")
    T.eq(fx["GetMerchantNumItems()"].values[1].value, 2, "a plain vendor fills the plain labels")
    T.eq(fx["gear:GetMerchantNumItems()"].values[1].value, 4, "and leaves the gear scene")
    T.eq(fx["merchant:GetMoney()"].values[1].value, 98765)
    gearIds[1] = true; vendorFakes(1)
    fire("MERCHANT_SHOW")
    T.eq(fx["GetMerchantNumItems()"].values[1].value, 2, "a third vendor records nothing")
end)

test("armed: a vendor whose item links are not loaded yet records nothing until it is opened again", function()
    local _, fire = probe({})
    vendorFakes(2)
    _G.GetMerchantItemLink = function() return nil end
    SlashCmdList.CTPROBE("record arm")
    fire("MERCHANT_SHOW")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(1)"], nil); T.eq(CTProbeDB.fixtures["gear:GetMerchantItemInfo(1)"], nil)
    T.ok(has("an item link is not loaded yet; open it again"), "the log says so")
    vendorFakes(2)
    fire("MERCHANT_UPDATE")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(2)"].values[1].value, "Item2")
end)

test("armed: a vendor row's item that is not cached is recorded when the client delivers it", function()
    local _, fire = probe({})
    vendorFakes(1)
    local cached = false
    _G.GetItemInfo = function(id) if cached then return "Late" .. id end end
    SlashCmdList.CTPROBE("record arm")
    fire("MERCHANT_SHOW")
    T.eq(CTProbeDB.fixtures["GetItemInfo(1)"].n, 0, "nothing yet")
    cached = true
    fire("GET_ITEM_INFO_RECEIVED", 1, true)
    T.eq(CTProbeDB.fixtures["GetItemInfo(1)"].values[1].value, "Late1"); T.eq(CTProbeDB.fixtures["GetItemInfo(1)"].window, "merchant", "the delivery keeps the tag")
end)

test("armed: a class trainer fills the class scene with more rows and the level requirement; a profession trainer the plain one", function()
    local _, fire = probe({})
    local tradeskill = false
    _G.IsTradeskillTrainer = function() return tradeskill end
    _G.GetNumTrainerServices = function() return 12 end
    _G.GetTrainerServiceInfo = function(i) return "Spell" .. i, "Rank " .. i, "available" end
    _G.GetTrainerServiceCost = function(i) return 10 * i end
    _G.GetTrainerServiceSkillReq = function() return nil end
    _G.GetTrainerServiceLevelReq = function(i) return 2 * i end
    _G.GetMoney = function() return 500 end
    SlashCmdList.CTPROBE("record arm")
    fire("TRAINER_SHOW")
    local fx = CTProbeDB.fixtures
    T.eq(fx["class:GetNumTrainerServices()"].values[1].value, 12)
    T.eq(fx["class:GetTrainerServiceInfo(10)"].values[2].value, "Rank 10", "a class trainer keeps ten rows")
    T.eq(fx["class:GetTrainerServiceInfo(11)"], nil)
    T.eq(fx["class:GetTrainerServiceLevelReq(4)"].values[1].value, 8)
    T.eq(fx["class:GetMoney()"].values[1].value, 500); T.eq(fx["class:GetMoney()"].window, "trainer")
    T.eq(fx["GetTrainerServiceInfo(1)"], nil, "the plain labels wait for a profession trainer")
    tradeskill = true
    fire("TRAINER_SHOW")
    T.eq(fx["GetTrainerServiceInfo(3)"].values[1].value, "Spell3"); T.eq(fx["GetTrainerServiceInfo(4)"], nil, "a profession trainer keeps three rows")
    T.eq(fx["trainer:GetMoney()"].values[1].value, 500)
end)

test("armed: one vendor opening fills one scene, even when the window updates", function()
    local _, fire = probe({})
    vendorFakes(3)
    _G.C_Item = _G.C_Item or {}
    _G.C_Item.GetItemInfoInstant = function(id) return id, "Weapon", "Maces", "INVTYPE_WEAPON", 1, 2, 4 end
    SlashCmdList.CTPROBE("record arm")
    fire("MERCHANT_SHOW"); fire("MERCHANT_UPDATE")
    T.ok(CTProbeDB.fixtures["gear:GetMerchantNumItems()"], "the weapon vendor fills gear")
    T.eq(CTProbeDB.fixtures["GetMerchantNumItems()"], nil, "and its update does not fill the plain scene")
    fire("MERCHANT_SHOW")
    T.ok(CTProbeDB.fixtures["GetMerchantNumItems()"], "a new opening fills the plain scene")
end)

test("armed: a trainer whose IsTradeskillTrainer answers nil is a class trainer", function()
    local _, fire = probe({})
    _G.IsTradeskillTrainer = function() return nil end
    _G.GetNumTrainerServices = function() return 2 end
    _G.GetTrainerServiceInfo = function(i) return "Spell" .. i end
    SlashCmdList.CTPROBE("record arm")
    fire("TRAINER_SHOW")
    T.ok(CTProbeDB.fixtures["class:GetNumTrainerServices()"], "Era answers 1 or nil")
    _G.IsTradeskillTrainer = function() return 1 end
    fire("TRAINER_UPDATE")
    T.eq(CTProbeDB.fixtures["GetNumTrainerServices()"], nil, "an update of the same trainer fills nothing more")
    fire("TRAINER_SHOW")
    T.eq(CTProbeDB.fixtures["GetNumTrainerServices()"].values[1].value, 2, "a profession trainer fills the plain scene")
end)

test("armed: a class trainer opened after the profession trainer still fills its scene", function()
    local _, fire = probe({})
    local tradeskill = 1
    _G.IsTradeskillTrainer = function() return tradeskill end
    _G.GetNumTrainerServices = function() return 2 end
    _G.GetTrainerServiceInfo = function(i) return (tradeskill and "Herb" or "Spell") .. i end
    SlashCmdList.CTPROBE("record arm")
    fire("TRAINER_SHOW")
    T.eq(CTProbeDB.fixtures["GetTrainerServiceInfo(1)"].values[1].value, "Herb1")
    tradeskill = nil
    fire("TRAINER_SHOW")
    T.eq(CTProbeDB.fixtures["class:GetTrainerServiceInfo(1)"].values[1].value, "Spell1", "the plain scene being full does not disarm the class scene")
    T.eq(CTProbeDB.armed.class, nil)
end)

test("armed: an auction row records its link", function()
    local _, fire = probe({})
    _G.GetNumAuctionItems = function() return 1, 1 end
    _G.GetAuctionItemInfo = function() return "Ore" end
    _G.GetAuctionItemLink = function(kind, i) return kind == "list" and "|Hitem:2770" .. i .. "|h" or nil end
    SlashCmdList.CTPROBE("record arm")
    fire("AUCTION_ITEM_LIST_UPDATE")
    T.eq(CTProbeDB.fixtures["GetAuctionItemLink(list,1)"].values[1].value, "|Hitem:27701|h"); T.eq(CTProbeDB.fixtures["GetAuctionItemLink(list,1)"].window, "auction")
    T.eq(CTProbeDB.fixtures["GetMoney()"], nil, "no money beside the auction house")
end)

finish()
