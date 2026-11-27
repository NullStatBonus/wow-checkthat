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
        rawset(f, "RegisterEvent", function(self, ev)
            if opts.noEvents and opts.noEvents[ev] then error("unknown event " .. ev) end -- a client without the event raises
            self.events[ev] = true
        end)
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
    T.eq(CTProbeDB.fixtures["GetMerchantNumItems()"], nil, "an empty list stores nothing, so a 0 never ships")
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

test("armed: a vendor whose names and links arrive late is recorded again by the next update of the same opening", function()
    local _, fire = probe({})
    vendorFakes(3)
    _G.GetMerchantItemLink = function() return nil end
    _G.GetMerchantItemInfo = function() return nil end
    SlashCmdList.CTPROBE("record arm")
    fire("MERCHANT_SHOW")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(1)"].values[1].type, "nil", "the first event's rows are kept for now")
    vendorFakes(2)
    fire("MERCHANT_UPDATE")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(2)"].values[1].value, "Item2", "the last update wins")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(3)"], nil, "a row the last update does not have is cleared")
    T.eq(CTProbeDB.fixtures["GetMerchantNumItems()"].values[1].value, 2)
    fire("MERCHANT_CLOSED"); vendorFakes(5); fire("MERCHANT_SHOW")
    T.eq(CTProbeDB.fixtures["GetMerchantNumItems()"].values[1].value, 2, "a new opening of a plain vendor does not replace the filled scene")
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
    T.eq(CTProbeDB.fixtures["GetMerchantNumItems()"], nil, "the plain scene takes only a vendor that sells no gear")
    T.ok(has("a gear vendor, and the gear scene is recorded already"), "the log says why")
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

test("v7: arming clears the window rows of an earlier run, so two vendors never mix", function()
    local _, fire = probe({})
    vendorFakes(3)
    SlashCmdList.CTPROBE("record arm"); fire("MERCHANT_SHOW")
    T.ok(CTProbeDB.fixtures["GetMerchantItemInfo(3)"])
    SlashCmdList.CTPROBE("record"); SlashCmdList.CTPROBE("record arm")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(3)"], nil, "the old row is gone")
    T.ok(CTProbeDB.fixtures["GetBuildInfo()"], "what /ctp record stored stays")
    vendorFakes(2); fire("MERCHANT_SHOW")
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(3)"], nil, "a shorter vendor leaves no row of the first")
end)

test("v7: a trainer's header rows are skipped and the real index is kept; kind and filter are recorded", function()
    local _, fire = probe({})
    _G.IsTradeskillTrainer = function() return nil end
    _G.GetNumTrainerServices = function() return 4 end
    _G.GetTrainerServiceInfo = function(i) if i == 1 or i == 3 then return "Cat" .. i, "", "header" end return "Spell" .. i, "Rank 1", "available" end
    _G.GetTrainerServiceTypeFilter = function(t) return t ~= "used" and 1 or nil end
    SlashCmdList.CTPROBE("record arm"); fire("TRAINER_SHOW")
    local fx = CTProbeDB.fixtures
    T.eq(fx["class:GetTrainerServiceInfo(1)"], nil, "a header is not a row")
    T.eq(fx["class:GetTrainerServiceInfo(2)"].values[1].value, "Spell2"); T.eq(fx["class:GetTrainerServiceInfo(4)"].values[1].value, "Spell4")
    T.eq(fx["class:IsTradeskillTrainer()"].values[1].type, "nil", "the 1 or nil answer is kept")
    T.eq(fx["class:GetTrainerServiceTypeFilter(used)"].values[1].type, "nil"); T.eq(fx["class:GetTrainerServiceTypeFilter(available)"].values[1].value, 1)
end)

test("v7: a trainer with no rows or only headers stores nothing and says to change the filter", function()
    local _, fire = probe({})
    _G.IsTradeskillTrainer = function() return nil end
    local n = 0
    _G.GetNumTrainerServices = function() return n end
    _G.GetTrainerServiceInfo = function(i) return "Cat" .. i, "", "header" end
    _G.GetTrainerServiceTypeFilter = function(t) return t ~= "used" end
    SlashCmdList.CTPROBE("record arm"); fire("TRAINER_SHOW")
    T.ok(has("no rows yet (filter"), "an empty list with the filter on waits: the rows come one update later")
    _G.GetTrainerServiceTypeFilter = function() return false end
    fire("TRAINER_UPDATE")
    T.ok(has("tick Available and Unavailable"), "an empty list with the filter off names the filter")
    _G.GetTrainerServiceTypeFilter = nil
    T.eq(CTProbeDB.fixtures["GetNumTrainerServices()"], nil, "no 0 count ships"); T.eq(CTProbeDB.armed.class, true)
    n = 2; fire("TRAINER_UPDATE")
    T.ok(has("only header rows"), "headers alone are not a recording"); T.eq(CTProbeDB.armed.class, true)
end)

test("v7: the plain trainer scene takes only a profession trainer", function()
    local _, fire = probe({})
    _G.IsTradeskillTrainer = function() return nil end
    _G.GetNumTrainerServices = function() return 1 end
    _G.GetTrainerServiceInfo = function() return "ClassSpell", "Rank 1", "available" end
    SlashCmdList.CTPROBE("record arm"); fire("TRAINER_SHOW"); fire("TRAINER_CLOSED"); fire("TRAINER_SHOW")
    T.eq(CTProbeDB.fixtures["GetTrainerServiceInfo(1)"], nil, "a second class trainer visit leaves the plain scene empty")
    T.eq(CTProbeDB.armed.trainer, true)
    T.ok(has("a class trainer, and the class scene is recorded already"))
end)

test("v7: the auction scene waits until every row has all its information", function()
    local _, fire = probe({})
    local all = false
    _G.GetNumAuctionItems = function() return 1, 1 end
    _G.GetAuctionItemInfo = function() return all and "Ore" or nil, 1, 1, 1, true, 1, "", 1, 1, 1, 0, false, nil, nil, nil, 0, 2770, all end
    SlashCmdList.CTPROBE("record arm"); fire("AUCTION_ITEM_LIST_UPDATE")
    T.eq(CTProbeDB.fixtures["GetAuctionItemInfo(list,1)"], nil); T.ok(has("rows not complete yet"))
    all = true; fire("AUCTION_ITEM_LIST_UPDATE")
    T.eq(CTProbeDB.fixtures["GetAuctionItemInfo(list,1)"].values[1].value, "Ore"); T.eq(CTProbeDB.armed.auction, nil)
end)

test("v7: a client without the auction event gets an error entry at arm, and the scene is not armed", function()
    probe({ noEvents = { AUCTION_ITEM_LIST_UPDATE = true } })
    SlashCmdList.CTPROBE("record arm")
    T.ok(CTProbeDB.fixtures["GetNumAuctionItems(list)"].error:find("not an event", 1, true))
    T.eq(CTProbeDB.armed.auction, nil)
end)

test("v7: an item delivered while its vendor is open records the vendor again; ids come from GetMerchantItemID", function()
    local _, fire = probe({})
    vendorFakes(1)
    local named = false
    _G.GetMerchantItemLink = function() return nil end
    _G.GetMerchantItemID = function(i) return 500 + i end
    _G.GetMerchantItemInfo = function(i) return named and "Late" or nil end
    SlashCmdList.CTPROBE("record arm"); fire("MERCHANT_SHOW")
    T.ok(CTProbeDB.fixtures["GetItemInfo(501)"], "the id came from GetMerchantItemID")
    named = true; fire("GET_ITEM_INFO_RECEIVED", 501, true)
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(1)"].values[1].value, "Late")
    fire("MERCHANT_CLOSED"); named = false; fire("GET_ITEM_INFO_RECEIVED", 501, true)
    T.eq(CTProbeDB.fixtures["GetMerchantItemInfo(1)"].values[1].value, "Late", "a closed vendor is not read again")
end)

test("v7: C_MerchantFrame.GetItemInfo keeps all eleven fields of its table", function()
    local _, fire = probe({})
    vendorFakes(1)
    _G.C_MerchantFrame = { GetItemInfo = function() local t = {}; for k = 1, 11 do t["f" .. k] = k end return t end }
    SlashCmdList.CTPROBE("record arm"); fire("MERCHANT_SHOW")
    local v = CTProbeDB.fixtures["C_MerchantFrame.GetItemInfo(1)"].values[1].value
    local n = 0; for _ in pairs(v) do n = n + 1 end
    T.eq(n, 11)
end)

test("v7: arming lasts one session, and record status names what is left", function()
    local _, fire = probe({})
    vendorFakes(1)
    SlashCmdList.CTPROBE("record arm"); fire("MERCHANT_SHOW")
    SlashCmdList.CTPROBE("record status")
    T.ok(has("recorded merchant; still waiting for gear, class, trainer, auction"), tostring(has("record status")))
    fire("ADDON_LOADED", "CTProbe")
    T.eq(CTProbeDB.armed, nil, "a reload ends the arming")
end)

local function forever()
    _G.C_AuctionHouse = {
        HasFullBrowseResults = function() return true end,
        GetBrowseResults = function() return { { itemKey = { itemID = 2589, itemLevel = 5, itemSuffix = 0, battlePetSpeciesID = 0 }, totalQuantity = 40, minPrice = 120, containsOwnerItem = false } } end,
        GetNumItemSearchResults = function(key) return key.itemID == 2589 and 2 or 0 end,
        HasFullItemSearchResults = function() return true end,
        GetItemKeyInfo = function(key) return { itemID = key.itemID, itemName = "Linen Cloth", quality = 1 } end,
        GetItemSearchResultInfo = function(key, i) if i <= 2 then return { itemKey = key, owners = { "Seller" .. i }, totalNumberOfOwners = 1, auctionID = 900 + i, quantity = 1, buyoutAmount = 100 * i, bidder = "Player-1-0000" } end end,
        GetNumCommoditySearchResults = function() return 1 end,
        HasFullCommoditySearchResults = function() return true end,
        GetCommoditySearchResultInfo = function(id, i) if i == 1 then return { itemID = id, quantity = 20, unitPrice = 15, auctionID = 77, owners = { "Seller" }, totalNumberOfOwners = 1, numOwnerItems = 0, containsOwnerItem = false, containsAccountItem = false } end end,
    }
end

test("v8: a table return is kept three levels deep, and a table cut short says so", function()
    probe({})
    vendorFakes(1)
    local deep = { a = { b = { c = { d = 1 } } } }
    local wide = {}
    for k = 1, 40 do wide[k] = k end
    _G.C_MerchantFrame = { GetItemInfo = function(i) return i == 1 and deep or wide end }
    local _, fire = probe({})
    vendorFakes(2)
    _G.C_MerchantFrame = { GetItemInfo = function(i) return i == 1 and deep or wide end }
    SlashCmdList.CTPROBE("record arm"); fire("MERCHANT_SHOW")
    local d = CTProbeDB.fixtures["C_MerchantFrame.GetItemInfo(1)"].values[1]
    T.eq(d.value.a.value.b.value.c.type, "table"); T.eq(d.value.a.value.b.value.c.cut, true, "the fourth level is cut")
    T.eq(d.cut, true, "and the cut shows at the top")
    T.eq(CTProbeDB.fixtures["C_MerchantFrame.GetItemInfo(2)"].values[1].cut, true, "a table with more than 32 keys is cut")
end)

test("v8: Forever auction searches are recorded as browse, itemsearch and commodity scenes, with the itemKey stored", function()
    local _, fire = probe({})
    forever()
    SlashCmdList.CTPROBE("record arm")
    T.eq(CTProbeDB.armed.browse, true); T.eq(CTProbeDB.armed.itemsearch, true); T.eq(CTProbeDB.armed.commodity, true)
    fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    local fx = CTProbeDB.fixtures
    local b = fx["C_AuctionHouse.GetBrowseResults()"]
    T.eq(b.window, "auction"); T.eq(b.values[1].value["1"].value.itemKey.value.itemID.value, 2589, "an array of results with their itemKey")
    T.eq(CTProbeDB.armed.browse, nil)
    local key = { itemID = 2589, itemLevel = 5, itemSuffix = 0, battlePetSpeciesID = 0 }
    fire("ITEM_SEARCH_RESULTS_UPDATED", key)
    local r = fx["C_AuctionHouse.GetItemSearchResultInfo(itemKey:2589,2)"]
    T.ok(r, "the label names the itemKey by its item"); T.eq(r.args[1].value.itemLevel.value, 5, "the whole itemKey is stored with the call")
    T.eq(r.args[2].value, 2)
    T.eq(fx["C_AuctionHouse.GetItemSearchResultInfo(itemKey:2589,3)"].n, 0, "a row past the results returns nothing")
    T.eq(fx["C_AuctionHouse.GetNumItemSearchResults(itemKey:2589)"].values[1].value, 2)
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
    T.eq(fx["C_AuctionHouse.GetCommoditySearchResultInfo(2589,1)"].values[1].value.unitPrice.value, 15)
    T.eq(fx["C_AuctionHouse.GetCommoditySearchResultInfo(2589,1)"].args, nil, "number arguments read back from the label")
    SlashCmdList.CTPROBE("record status")
    T.ok(has("recorded browse, itemsearch, commodity") or has("browse, itemsearch, commodity;"), tostring(has("record status")))
end)

test("v8: the last search of an open auction house wins, and closing it ends the scene", function()
    local _, fire = probe({})
    forever()
    SlashCmdList.CTPROBE("record arm")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2592)
    T.eq(CTProbeDB.fixtures["C_AuctionHouse.GetCommoditySearchResultInfo(2589,1)"], nil, "the earlier search is cleared")
    T.ok(CTProbeDB.fixtures["C_AuctionHouse.GetCommoditySearchResultInfo(2592,1)"])
    fire("AUCTION_HOUSE_CLOSED"); fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2600)
    T.eq(CTProbeDB.fixtures["C_AuctionHouse.GetCommoditySearchResultInfo(2600,1)"], nil, "a search after closing records nothing")
end)

test("v8: a client without C_AuctionHouse does not arm the Forever auction scenes", function()
    probe({})
    _G.C_AuctionHouse = nil
    SlashCmdList.CTPROBE("record arm")
    T.eq(CTProbeDB.armed.browse, nil); T.eq(CTProbeDB.armed.commodity, nil)
end)

test("v8: /ctp record arm with scene names arms only those, and names one the client lacks", function()
    probe({})
    _G.C_AuctionHouse = nil
    SlashCmdList.CTPROBE("record arm class merchant browse")
    T.same(CTProbeDB.armed, { class = true, merchant = true })
    T.ok(has("not a scene on this client: browse"), "Era has no browse scene")
    SlashCmdList.CTPROBE("record status")
    T.ok(has("record status: recorded nothing; still waiting for merchant, class"), tostring(has("record status")))
end)

test("the focused in-game run: Forever vendor, class trainer and auction searches, then Era's class trainer, end with nothing left", function()
    local _, fire = probe({ client = "forever", noEvents = { AUCTION_ITEM_LIST_UPDATE = true } })
    forever()
    vendorFakes(3)
    _G.GetMerchantItemInfo = nil -- a nil global on Forever
    _G.C_MerchantFrame = { GetItemInfo = function(i) return { name = "Thread" .. i, texture = 1, price = 10 * i, stackCount = 1, numAvailable = -1, isPurchasable = true, isUsable = true, hasExtendedCost = false, isQuestStartItem = false } end }
    _G.C_Item = _G.C_Item or {}; _G.C_Item.GetItemInfoInstant = function(id) return id, "Trade Goods", "Cloth", "", 1, 7, 0 end
    _G.IsTradeskillTrainer = function() return false end
    _G.GetNumTrainerServices = function() return 3 end
    _G.GetTrainerServiceInfo = function(i) return "Spell" .. i, i == 1 and "header" or "available", 1, 2, "Rank 1", "" end
    SlashCmdList.CTPROBE("record")
    SlashCmdList.CTPROBE("record arm merchant class browse itemsearch commodity")
    fire("MERCHANT_SHOW"); fire("MERCHANT_UPDATE"); fire("MERCHANT_CLOSED")
    fire("TRAINER_SHOW"); fire("TRAINER_UPDATE"); fire("TRAINER_CLOSED")
    fire("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
    fire("COMMODITY_SEARCH_RESULTS_UPDATED", 2589)
    fire("ITEM_SEARCH_RESULTS_UPDATED", { itemID = 2589, itemLevel = 5, itemSuffix = 0, battlePetSpeciesID = 0 })
    SlashCmdList.CTPROBE("record status")
    T.ok(has("recorded merchant, class, browse, itemsearch, commodity; still waiting for nothing"), tostring(has("record status")))
    local fx = CTProbeDB.fixtures
    T.eq(fx["C_MerchantFrame.GetItemInfo(2)"].values[1].value.price.value, 20, "the Forever vendor price")
    T.ok(fx["GetMerchantItemInfo(1)"].error, "the missing legacy call is an error entry")
    T.eq(fx["class:GetTrainerServiceInfo(2)"].values[1].value, "Spell2", "the header row 1 is skipped")
    T.ok(fx["GetNumAuctionItems(list)"].error:find("not an event", 1, true))
    local _, fireEra = probe({})
    _G.C_AuctionHouse = nil
    _G.IsTradeskillTrainer = function() return nil end
    _G.GetNumTrainerServices = function() return 2 end
    _G.GetTrainerServiceInfo = function(i) return "Spell" .. i, "Rank " .. i, "available", 1 end
    SlashCmdList.CTPROBE("record"); SlashCmdList.CTPROBE("record arm class")
    fireEra("TRAINER_SHOW")
    SlashCmdList.CTPROBE("record status")
    T.ok(has("recorded class; still waiting for nothing"), tostring(has("record status")))
end)

finish()
