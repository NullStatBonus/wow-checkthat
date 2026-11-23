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
finish()
