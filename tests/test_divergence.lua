-- Globals that CheckThat's own files read as nil while the whole TOC loads and runs in the fake client. The list is
-- the places where the fake client may differ from the game. Reviewed in tests/fixtures/nil-reads.txt.
local ns, test, T, finish, H = dofile("tests/harness.lua")()
local st = H.stubClient()

local function baseline()
    local out = {}
    for l in io.lines("tests/fixtures/nil-reads.txt") do
        local name = l:match("^%s*([%w_]+)%s*$")
        if name then out[name] = true end
    end
    return out
end

test("CheckThat reads only the nil globals that the baseline accepts", function()
    local stop = H.recordNilReads({ "@CheckThat/" }, { "/libs/" })
    H.loadToc(ns, "CheckThat/CheckThat_Vanilla.toc")
    local addon = ns.addon
    CheckThatDB = nil
    addon:OnInitialize()
    addon:OnEnable()
    -- Drive the screens a player uses: import, start, the card, its prompts, the settings window and the slash handler.
    local f = io.open("build/keepthat.ct"); local s = f:read("*a"); f:close()
    ns.App.ImportPlan(s); ns.App.Start("KeepThat")
    ns.Card.Show(); ns.Card.Refresh(); ns.Card.ImportPrompt()
    pcall(ns.Options.Open)
    for _, cmd in ipairs({ "log", "help", "status", "stop", "plans" }) do pcall(ns.Slash.Run, cmd, { card = function() ns.Card.Show() end }) end
    pcall(ns.Card.RunMenu, _G.CheckThatCard); pcall(ns.Card.ConfirmEnd)
    local got = stop()
    local known, new, gone, seen = baseline(), {}, {}, {}
    for _, n in ipairs(got) do
        seen[n] = true
        if not known[n] then new[#new + 1] = n end
    end
    for n in pairs(known) do if not seen[n] then gone[#gone + 1] = n end end
    table.sort(gone)
    if #new > 0 then error("New nil reads: " .. table.concat(new, " ") .. ". Add each to tests/fixtures/nil-reads.txt with a reason, or guard it in Core/Adapter.lua.", 0) end
    if #gone > 0 then error("No longer read as nil: " .. table.concat(gone, " ") .. ". Remove each from tests/fixtures/nil-reads.txt.", 0) end
end)
finish()
