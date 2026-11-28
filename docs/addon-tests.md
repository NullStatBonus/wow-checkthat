# Test your addon's Lua

`ct test` runs your addon's own tests in the fake client that `ct offline` uses. You get the client's real functions and events, its load order and saved variables, combat, a virtual clock, and the nil-read report. Each test gets a fresh load of your addon, on each client you have a TOC for. It needs LuaJIT (`ct doctor` says how to install it).

## Write a test

Put test files in your addon's folder as `tests/test_<name>.lua` or `tests/<name>_test.lua`. A file that never names `ct.test` is left out, so the files of your own test runner can sit in the same folder: `ct test` lists them as skipped. A file gets `ct` as its `...`, and `ct.test(name, fn)` registers a test. The test function gets `ctx`, the same object a plan's [Lua hook](authoring-plans.md#lua-hooks-level-5-and-later) gets. `ctx.ns` is your addon's private namespace (the second value of `...` in its files).

```lua
-- MyAddon/tests/test_bags.lua
local ct = ...

ct.test("a bag update is counted", function(ctx)
    ctx.fire("BAG_UPDATE", 0)
    ctx.eq(ctx.ns.count, 1, "updates")
end)

ct.test("the setting stays on after a reload", { savedVariables = { MyAddonDB = { on = true } } }, function(ctx)
    ctx.reload()
    ctx.eq(MyAddonDB.on, true, "on")
end)

ct.test("money comes from the mock", { mocks = { GetMoney = { returns = { 12345 } } } }, function(ctx)
    ctx.eq(ctx.ns.Money(), 12345, "money")
end)

ct.test("selling stops in combat", function(ctx)
    ctx.combat(true)
    ctx.raises(ctx.ns.SellJunk, "in combat")
end)
```

The optional second value of `ct.test` holds `mocks` and `savedVariables`, in the same shapes as an offline block's ([Offline checks](authoring-plans.md)), and `checkThat` ([Test your CheckThat integration](#test-your-checkthat-integration)). A mock is set before your addon loads. A `{ recording = "..." }` mock reads the bundled recordings, and also your own when you pass `--recordings`. A test passes when its function returns, and fails with the error text when it raises or your addon does not load.

## Test your CheckThat integration

Your addon gets CheckThat's own public API as the global `CheckThat`, with the game's rules ([Public API of CheckThat](contracts.md#public-api-of-checkthat)): `API_VERSION` 4, `Entry`, `OnRun`, `ActiveRun`, `Commands` and `Report`. `Report` records only while a run is open, as in game. A test opens and ends runs with `ctx.run`, calls your entries with `ctx.entry` and reads your facts with `ctx.reports`:

```lua
ct.test("a run turns test mode on and off", function(ctx)
    ctx.run("start", { plan = "Bags" })
    ctx.eq(ctx.ns.testMode, true, "test mode")
    ctx.eq(CheckThat.ActiveRun("MyAddon"), "Bags", "ActiveRun")
    ctx.same(ctx.reports(), { "[MyAddon] mode=test" }, "facts")
    ctx.run("end")
    ctx.eq(ctx.ns.testMode, nil, "test mode off")
end)

ct.test("the count entry", function(ctx)
    ctx.fire("BAG_UPDATE", 0)
    ctx.eq(ctx.entry("count"), 1, "entry.count")
end)

ct.test("CheckThat loads after the addon", { checkThat = "late" }, function(ctx)
    ctx.eq(ctx.entry("count"), 0, "registered by PLAYER_LOGIN")
end)
```

`checkThat` says when CheckThat loads:

- `"early"` (the default): before your addon, so `CheckThat` is there when your first file runs. The game does this when your TOC names CheckThat in `## Dependencies` or `## OptionalDeps`, or your addon's name sorts after CheckThat's.
- `"late"`: after your addon. `CheckThat` is nil while your files run and at your `ADDON_LOADED`. Then `ADDON_LOADED` fires with `"CheckThat"`, before `VARIABLES_LOADED`. CheckThat sets its global while it handles that event, and which addon gets the event first is not measured, so `ct test` gives the global only after your handlers have run. Look for `CheckThat` again at `PLAYER_LOGIN`. The game loads CheckThat after your addon when your addon's name sorts before CheckThat's and your TOC does not name it as a dependency.
- `"missing"`: no CheckThat at all, as for a player who does not have it installed.

`CheckThat` is left out of the nil-read report, because the test chose whether it is there.

## Run it

From your addon's folder (the one with its TOC files):

```
<ct>/tools/ct test
```

`<ct>` is the tools folder of your install ([Skills](skills.md)). Options:

- `ct test MyAddon` names the addon's folder instead.
- `--client era` or `--client forever` runs one client. By default each client you have a TOC for runs.
- `--name TEXT` runs only the tests whose name contains the text.
- `--recordings DIR` adds your own recordings folder (`ct recordings -o`, see [Record your own calls](authoring-plans.md#record-your-own-calls)).
- `--tests DIR` runs the `test_*.lua` and `*_test.lua` files in that folder instead of the addon's `tests/`. Use it when your repo keeps its tests outside the folder it ships, such as `ct test MyAddon --tests ../tests`. Files there that never name `ct.test` are skipped. A file that names `ct.test` but registers no test fails.

It prints a line for each test on each client, then the globals your addon read as nil on each client, then a summary:

```
ok    era      tests/test_bags.lua  a bag update is counted
FAIL  forever  tests/test_bags.lua  money comes from the mock: threw .../MyAddon/tests/test_bags.lua:17: money: expected 12345, got nil
...
test: 7 passed, 1 failed
```

It exits 0 when every test passes, 1 when one fails, and 2 when it cannot run: no TOC with an `## Interface:` line, no `test_*.lua` or `*_test.lua` that names `ct.test` in `tests/` (or in the `--tests` folder), no TOC for the client you named, or no test matching `--name`.

## Good to know

- **Which TOC.** The `## Interface:` number decides the client: 10000 to 15999 is Era, 16000 to 19999 is Forever. A TOC for any other client, such as retail, is left out. A comma list counts for each number, and each client runs with its own number. When two TOCs are for the same client, the suffix that client reads wins (`_Vanilla` or `_Classic` for Era, `_Camelot` for Forever), then any other suffix, then the plain `MyAddon.toc`.
- **The addon's name.** Your addon gets its name as the first value of `...` and in `ADDON_LOADED`. It is the folder's name when a TOC is named after the folder. Otherwise it is the name your TOC files share, so a checkout folder such as `my-repo` still loads as `MyAddon`. TOC files that share no name are an error.
- **Isolation.** Each test file runs in its own process for each client, from your addon's folder. Each test gets a fresh load, so the tests in a file do not share the fake client. Locals at the top of your file are shared, as in any Lua file.
- **Helpers.** `require("helper")` loads `tests/helper.lua`, and `dofile("tests/helper.lua")` works too. What any file in `tests/` reads as nil stays out of your addon's nil-read report.
- **Output.** `print` inside a test goes to the fake client's chat, as in game. To see a value, use `io.write`. `ct test` shows what a file wrote under its lines, marked with `|`.
- **Time limit.** A test file that runs longer than 300 seconds on a client is stopped and fails.
- **ctx.reload** runs from the test itself, not from a handler or timer the test fires.
- **Facts at a run's end.** CheckThat closes the run before it calls your `OnRun` function with `"end"`, so a fact you report from that call is not recorded. The same happens in game.
- **A run open at a reload.** After `ctx.reload()`, your `OnRun` function gets `"start"` when it registers. With `"early"` that can be at file scope, before your saved variables are there. An error in that call fails `ctx.reload`.
- **Facts per second.** `Report` keeps at most 30 facts a second for each addon, as in game. The clock moves only with `ctx.advance`, so a test that reports more than 30 facts without it loses the rest.
- **ctx.entry** reaches only the entries your addon registered under its own name. It returns nil both for an entry that is not there and for one that returns nothing; check `CheckThat.Entry`'s return value to know it was stored.
- **Budget.** An entry or an `OnRun` function that `ctx.entry` or `ctx.run` calls has the same script-time limit as a handler, so a runaway loop fails the test instead of running to the file's time limit.
- **What runs where.** Your test function runs with Lua's full library (`io`, `os`, `require` and the rest). Your addon's code that `ctx.fire`, `ctx.advance` and `ctx.reload` run sees only what it sees in game. A function you call straight from a test, such as `ctx.ns.SellJunk()`, runs with the test's library. A global your test file reads as nil is not in your addon's nil-read report.
- **Trust.** `ct test` runs your addon's Lua and your tests with your permissions. Use it on code you trust.
- **What a pass proves.** A test can change anything in the fake client, so a pass proves what the test checks. The fake client models the game's answers. The game itself can differ, so keep an in-game plan for what only the game shows.
- **Stable.** `ct test`, `ct.test`, `ct.API` (1) and every `ctx` field are stable. A change only adds. CheckThat's own `tests/harness.lua` is internal.

## The ctx reference

The table is in [Lua hooks](authoring-plans.md#lua-hooks-level-5-and-later). A test uses `ctx.reload`, `ctx.ok`, `ctx.raises`, `ctx.entry`, `ctx.reports` and `ctx.run` most. A hook step can use all of them except `ctx.run`.
