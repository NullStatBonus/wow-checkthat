-- CheckThat under each client's real surface (tools/clients/*.json, issue 145): only the game functions that client has,
-- its real build, and frames with only their widget type's methods. Each client loads its own TOC.
local ns0, test, T, finish, H = dofile("tests/harness.lua")()
local restore = H.snapshot()

local function planText()
    local f = assert(io.open("build/keepthat.ct")); local s = f:read("*a"); f:close()
    return s
end

for client, toc in pairs({ era = "CheckThat/CheckThat_Vanilla.toc", forever = "CheckThat/CheckThat_Camelot.toc" }) do
    test(client .. ": CheckThat loads, enables, runs a plan and exports under the client's surface", function()
        restore()
        local st = H.stubClient({ client = client })
        local ns = {}
        H.loadToc(ns, toc)
        T.ok(ns.addon, "AceAddon created")
        CheckThatDB = nil
        ns.addon:OnInitialize()
        ns.addon:OnEnable()
        T.eq(_G.CheckThat.API_VERSION, 2)
        T.ok(ns.App.ImportPlan(planText()))
        local lines = ns.Slash.Run("start KeepThat", { card = function() ns.Card.Show() end })
        T.ok(lines[1]:find("Started"), lines[1])
        for _ = 1, 3 do ns.Card.Refresh(); ns.App.Verdict("skip") end
        ns.Card.Refresh(); ns.Card.ApplyAppearance(); ns.Card.MakeMacro()
        T.ok(ns.App.Export())
        T.ok(ns.Log.Report():find("CheckThat"))
        T.eq(select(4, GetBuildInfo()), st.surface.interface)
    end)
end

test("the surfaces differ where the clients differ", function()
    restore()
    _G.GetItemInfo = function() return "left over" end -- as an earlier fake client or a test left it
    H.stubClient({ client = "forever" })
    T.eq(rawget(_G, "GetItemInfo"), nil, "Forever has only C_Item.GetItemInfo")
    T.eq(type(C_Item.GetItemInfo), "function")
    restore()
    H.stubClient({ client = "era" })
    T.eq(type(GetItemInfo), "function")
    T.eq(select(2, GetBuildInfo()), "70576")
end)

test("a frame of a listed type has only its type's methods; a frame from a template takes any", function()
    restore()
    H.stubClient({ client = "era" })
    local f = CreateFrame("Frame")
    T.eq(f.SetPointt, nil, "a typo reads nil")
    T.ok(not pcall(function() f:SetPointt("CENTER") end), "and calling it fails")
    T.eq(type(f.SetPoint), "function")
    T.eq(type(CreateFrame("Button").SetText), "function")
    T.eq(CreateFrame("Frame").SetText, nil, "a plain Frame has no SetText")
    T.eq(type(CreateFrame("Frame", nil, nil, "BackdropTemplate").SetBackdrop), "function", "templates are not modelled yet")
    T.eq(UIParent:CreateTexture().SetText, nil, "a texture has no SetText")
end)

test("Lua aliases are the real functions, and other missing functions are stubs that return nothing", function()
    restore()
    local st = H.stubClient({ client = "era" })
    T.eq(strsub("abc", 2), "bc"); T.eq(tinsert, table.insert); T.eq(mod(7, 3), 1)
    T.ok(st.generated.GetHaste, "GetHaste is generated"); T.eq(GetHaste(), nil)
    T.eq(st.generated.UnitName, nil, "hand-written behaviour stays")
end)

test("the client lacks what the game lacks: dofile, load, loadfile, module and require", function()
    restore()
    H.stubClient({ client = "era" })
    for _, n in ipairs({ "dofile", "load", "loadfile", "module", "require" }) do T.eq(rawget(_G, n), nil, n) end
    T.eq(type(pcall), "function"); T.eq(type(setmetatable), "function")
    restore()
    T.eq(type(loadfile), "function", "restore brings them back")
end)

test("a C_ table an earlier fake client made is not changed in place", function()
    restore()
    local mine = { GetItemCount = function() return 7 end }
    _G.C_Item = mine
    local snap = H.snapshot()
    H.stubClient({ client = "era" })
    T.ok(C_Item ~= mine and type(C_Item.GetItemInfo) == "function")
    snap()
    T.eq(C_Item, mine); T.eq(mine.GetItemInfo, nil, "the earlier table keeps only its own members")
    T.eq(mine.GetItemCount(), 7)
end)

test("game helpers work: degrees for trig, Mixin, CopyTable, strtrim, strjoin, tContains", function()
    restore()
    H.stubClient({ client = "forever" })
    T.ok(math.abs(sin(90) - 1) < 1e-9); T.ok(math.abs(atan2(1, 1) - 45) < 1e-9)
    local o = CreateFromMixins({ a = 1 }, { b = 2 }); T.eq(o.a + o.b, 3)
    local t = { x = { 1 } }; local c = CopyTable(t); T.ok(c.x ~= t.x and c.x[1] == 1)
    T.eq(strtrim("  hi  "), "hi"); T.eq(strtrim("xxhixx", "x"), "hi"); T.eq(strjoin(",", "a", "b"), "a,b")
    T.eq(tContains({ "a" }, "a"), true); T.eq(type(date("%Y")), "string")
end)

test("CreateFrame types are matched without regard to case, and a misspelled client fails", function()
    restore()
    H.stubClient({ client = "era" })
    T.eq(CreateFrame("frame").SetPointt, nil)
    restore()
    T.ok(not pcall(H.stubClient, { client = "Era" }), "a client name with no surface is an error")
end)

test("without a client the fake client is unchanged", function()
    restore()
    H.stubClient()
    T.eq(select(4, GetBuildInfo()), 11507)
    T.eq(type(CreateFrame("Frame").SetPointt), "function")
end)

finish()
