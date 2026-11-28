# Test your addon's Lua

`ct test` runs your addon's own tests in the fake client that `ct offline` uses. You get the client's real functions and events, its load order and saved variables, combat, a virtual clock, and the nil-read report. Each test gets a fresh load of your addon, on each client you have a TOC for. It needs LuaJIT (`ct doctor` says how to install it).

## Write a test

Put test files in your addon's folder as `tests/test_<name>.lua`. A file gets `ct` as its `...`, and `ct.test(name, fn)` registers a test. The test function gets `ctx`, the same object a plan's [Lua hook](authoring-plans.md#lua-hooks-level-5-and-later) gets. `ctx.ns` is your addon's private namespace (the second value of `...` in its files).

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

The optional second value of `ct.test` holds `mocks` and `savedVariables`, in the same shapes as an offline block's ([Offline checks](authoring-plans.md)). A mock is set before your addon loads. A `{ recording = "..." }` mock reads the bundled recordings, and also your own when you pass `--recordings`. A test passes when its function returns, and fails with the error text when it raises or your addon does not load.

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
- `--tests DIR` runs the `test_*.lua` files in that folder instead of the addon's `tests/`. Use it when your repo keeps its tests outside the folder it ships, such as `ct test MyAddon --tests tests/ct`. Keep `ct` test files in their own folder: a file that registers no `ct.test` fails.

It prints a line for each test on each client, then the globals your addon read as nil on each client, then a summary:

```
ok    era      tests/test_bags.lua  a bag update is counted
FAIL  forever  tests/test_bags.lua  money comes from the mock: threw .../MyAddon/tests/test_bags.lua:17: money: expected 12345, got nil
...
test: 7 passed, 1 failed
```

It exits 0 when every test passes, 1 when one fails, and 2 when it cannot run: no TOC with an `## Interface:` line, no `tests/test_*.lua` (or no `test_*.lua` in the `--tests` folder), no TOC for the client you named, or no test matching `--name`.

## Good to know

- **Which TOC.** The `## Interface:` number decides the client: 10000 to 15999 is Era, 16000 to 19999 is Forever. A TOC for any other client, such as retail, is left out. A comma list counts for each number, and each client runs with its own number. When two TOCs are for the same client, the suffix that client reads wins (`_Vanilla` or `_Classic` for Era, `_Camelot` for Forever), then any other suffix, then the plain `MyAddon.toc`.
- **The addon's name.** Your addon gets its name as the first value of `...` and in `ADDON_LOADED`. It is the folder's name when a TOC is named after the folder. Otherwise it is the name your TOC files share, so a checkout folder such as `my-repo` still loads as `MyAddon`. TOC files that share no name are an error.
- **Isolation.** Each test file runs in its own process for each client, from your addon's folder. Each test gets a fresh load, so the tests in a file do not share the fake client. Locals at the top of your file are shared, as in any Lua file.
- **Helpers.** `require("helper")` loads `tests/helper.lua`, and `dofile("tests/helper.lua")` works too. What any file in `tests/` reads as nil stays out of your addon's nil-read report.
- **Output.** `print` inside a test goes to the fake client's chat, as in game. To see a value, use `io.write`. `ct test` shows what a file wrote under its lines, marked with `|`.
- **Time limit.** A test file that runs longer than 300 seconds on a client is stopped and fails.
- **ctx.reload** runs from the test itself, not from a handler or timer the test fires.
- **What runs where.** Your test function runs with Lua's full library (`io`, `os`, `require` and the rest). Your addon's code that `ctx.fire`, `ctx.advance` and `ctx.reload` run sees only what it sees in game. A function you call straight from a test, such as `ctx.ns.SellJunk()`, runs with the test's library. A global your test file reads as nil is not in your addon's nil-read report.
- **Trust.** `ct test` runs your addon's Lua and your tests with your permissions. Use it on code you trust.
- **What a pass proves.** A test can change anything in the fake client, so a pass proves what the test checks. The fake client models the game's answers. The game itself can differ, so keep an in-game plan for what only the game shows.
- **Stable.** `ct test`, `ct.test`, `ct.API` (1) and every `ctx` field are stable. A change only adds. CheckThat's own `tests/harness.lua` is internal.

## The ctx reference

The table is in [Lua hooks](authoring-plans.md#lua-hooks-level-5-and-later). A test uses `ctx.reload`, `ctx.ok` and `ctx.raises` most. A hook step can use them too.
