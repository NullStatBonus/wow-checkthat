local ns, test, T, finish, H = dofile("tests/harness.lua")()
-- The text window (report, results string, plan import) must draw above the card and the protected Run button.
local st = H.stubClient()
local real = _G.CreateFrame
_G.CreateFrame = function(kind, name, ...)
    local f = real(kind, name, ...)
    f.SetFrameStrata = function(self, s) self.strata = s end -- the stub does not keep it; remember it for the test
    return f
end
H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
local RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
test("the text window draws above the card and the Run button", function()
    CheckThatDB = nil
    ns.addon:OnInitialize(); ns.addon:OnEnable()
    ns.Card.Show()
    local card = _G.CheckThatCard
    T.ok(card.secure, "the Run button exists")
    ns.Export.Prompt("Results", "!CT1!x", nil, "Close", "", true, { choices = {} }) -- the stub frame answers any missing field with a function
    local box = _G.CheckThatTextBox
    T.ok(box, "the window exists")
    T.ok(RANK[box.strata], "window strata is set: " .. tostring(box.strata))
    T.ok(RANK[card.secure.strata] and RANK[box.strata] > RANK[card.secure.strata],
        ("window (%s) must be above the Run button (%s)"):format(tostring(box.strata), tostring(card.secure.strata)))
    T.ok(RANK[box.strata] > RANK[rawget(card, "strata") or "MEDIUM"], "and above the card")
end)
-- Game globals stay in Core/Adapter.lua. UI/ and Debug/ may build their own frames (AGENTS.md, Conventions).
test("Model, Options and Core use no game globals outside the adapter", function()
    local GLOBALS = { "CreateFrame", "UIParent", "InCombatLockdown", "GetTime", "hooksecurefunc", "GameTooltip", "GetBuildInfo" }
    local bad = {}
    local p = io.popen("find CheckThat/Model CheckThat/Options CheckThat/Core -name '*.lua' ! -name Adapter.lua")
    for path in p:lines() do
        local n = 0
        for line in io.lines(path) do
            n = n + 1
            line = " " .. line:gsub("%-%-.*$", "") .. " "
            for _, g in ipairs(GLOBALS) do
                -- a bare name: not a field (x.G, x:G) and not part of a longer name
                if line:find("[^%w_.:]" .. g .. "[^%w_]") then bad[#bad + 1] = ("%s:%d %s"):format(path, n, g) end
            end
            -- C_* namespaces
            if line:find("[^%w_.:\"']C_%u%w*%.") then bad[#bad + 1] = ("%s:%d C_*"):format(path, n) end
        end
    end
    p:close()
    T.ok(#bad == 0, "game globals outside the adapter: " .. table.concat(bad, ", "))
end)
finish()
