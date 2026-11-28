-- Fixture: a developer's own tests, run by ct test (docs/addon-tests.md). Not shipped.
local ct = ...

ct.test("a bag update is counted", function(ctx)
    ctx.eq(ctx.ns.count, 0, "before")
    ctx.fire("BAG_UPDATE", 0)
    ctx.eq(ctx.ns.count, 1, "after")
end)

ct.test("the saved count goes on across a reload", { savedVariables = { TestedAddonDB = { runs = 4 } } }, function(ctx)
    ctx.eq(ctx.ns.runs, 5, "first load")
    ctx.reload()
    ctx.eq(ctx.ns.runs, 6, "after the reload")
end)

ct.test("money comes from the mock", { mocks = { GetMoney = { returns = { 12345 } } } }, function(ctx)
    ctx.eq(ctx.ns.Money(), 12345, "money")
    ctx.eq(ctx.mockCalls("GetMoney"), 1, "calls")
end)

ct.test("selling stops in combat", function(ctx)
    ctx.ok(ctx.ns.Sell(), "out of combat")
    ctx.combat(true)
    ctx.raises(ctx.ns.Sell, "in combat", "in combat")
end)

ct.test("the suffixed TOC was loaded", function(ctx)
    ctx.ok(not ctx.ns.plain, "the plain TOC stays out")
    ctx.eq(ctx.ns.name, "TestedAddon", "the addon's name, whatever its folder is called")
    ctx.ok(ctx.client == "era" or ctx.client == "forever", "client")
end)
