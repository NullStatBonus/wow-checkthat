-- Fixture: tests of the addon's CheckThat integration, run by ct test (docs/addon-tests.md). Not shipped.
local ct = ...

ct.test("CheckThat's API is there before the addon loads", function(ctx)
    ctx.eq(ctx.ns.ct.api, 4, "API_VERSION")
    ctx.ok(ctx.ns.ct.commands, "Commands stored the prefix")
    ctx.eq(ctx.entry("count"), 0, "entry")
    ctx.fire("BAG_UPDATE", 0)
    ctx.eq(ctx.entry("count"), 1, "entry after an update")
    ctx.eq(ctx.entry("nope"), nil, "no such entry")
    ctx.raises(function() ctx.entry("fail") end, "entry broke", "a throwing entry")
end)

ct.test("a run turns test mode on and off, and facts are recorded only while it is open", function(ctx)
    ctx.eq(ctx.ns.ct.active, nil, "no run at load")
    ctx.eq(CheckThat.Report("TestedAddon", "early", 1), false, "Report outside a run")
    ctx.run("start", { plan = "Bags" })
    ctx.eq(ctx.ns.testMode, true, "test mode")
    ctx.eq(CheckThat.ActiveRun("TestedAddon"), "Bags", "ActiveRun")
    ctx.run("end")
    ctx.eq(ctx.ns.testMode, nil, "test mode off")
    ctx.same(ctx.ns.ct.events, { "start:Bags", "end:ended" }, "OnRun events")
    -- In game the run is closed when "end" comes, so the fact the callback reports then is dropped.
    ctx.same(ctx.reports(), { "[TestedAddon] mode=test" }, "facts")
end)

ct.test("a run stays open across a reload and starts again", function(ctx)
    ctx.run("start", { plan = "Bags" })
    ctx.reload()
    ctx.eq(ctx.ns.ct.active, "Bags", "ActiveRun at load")
    ctx.same(ctx.ns.ct.events, { "start:Bags" }, "start again after the reload")
    ctx.eq(ctx.ns.testMode, true, "test mode again")
end)

ct.test("CheckThat that loads after the addon is found by PLAYER_LOGIN", { checkThat = "late" }, function(ctx)
    ctx.eq(ctx.ns.ct.api, 4, "hooked late")
    ctx.eq(ctx.entry("count"), 0, "entry")
end)

ct.test("the addon runs without CheckThat", { checkThat = "missing" }, function(ctx)
    ctx.eq(ctx.ns.ct.api, "none", "no API")
    ctx.eq(CheckThat, nil, "no global")
    ctx.eq(ctx.entry("count"), nil, "no entry")
end)
