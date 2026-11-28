# Design

## Context

`tools/entry_runner.lua` sets a small fake `CheckThat` global before each load (`Entry`, `Report`, `API_VERSION = 2`, `PROTOTYPE`). `Report` records at any time. `ct test` (#273, same PR) reuses the runner with one hook step per test. CheckThat's own public table is `Facts.API()` in `CheckThat/Model/Facts.lua`; it delegates to `Entries`, `RunEvents` and `App.DeclareCommands`. `Facts`, `Entries` and `RunEvents` are plain Lua with a `Bind` function for their state, and the bundle already ships `CheckThat/`.

## Goals / Non-Goals

**Goals:**
- An addon's CheckThat integration runs offline the way it runs in game: same API table, same rules, both load orders, and without CheckThat.
- A test can drive and observe that integration: call entries, read facts, open and end runs.

**Non-Goals:**
- Offline blocks keep today's fake. Giving them the full API could change a plan's result (an addon that sees `OnRun` takes another path), so it would need a new offline level and plan-format work. Tracked as an issue if a plan needs it.
- The fake does not read plans or record runs. `ctx.run` only drives `OnRun` and `ActiveRun` and opens `Report`.
- A `ctx` field to read the commands from `Commands`. Its return value is what the addon sees.

## Decisions

- **Reuse CheckThat's modules, not a copy.** For each load the runner loads `Facts.lua`, `Entries.lua` and `RunEvents.lua` from the bundled `CheckThat/Model/` into a fresh namespace, binds them (`Facts.Bind(store, clock, open)`, `RunEvents.Bind(open)`) and sets `_G.CheckThat = Facts.API()`. A reload loads them again, as the game reloads CheckThat. The rules then cannot drift from the game's. `Entry` is wrapped so the runner also keeps the function, for `ctx.entry`.
- **`Commands`** needs `App.DeclareCommands`, and `App.lua` needs the whole addon. `Runner.declareCommands` makes the same checks on the bundled `Plan.lua` rules (`ADDON_NAME`, `COMMANDS_MAX`, `CommandProblem`). It is a copy, so `tests/test_app.lua` compares both over a table of inputs and fails when they drift. Moving the checks into `Plan` would change addon code.
- **The open run lives outside the load**, so it survives `ctx.reload()`. After a reload, `start` comes again when the addon registers `OnRun`, as in the game (`RunEvents.Register` sends `start` for an open run).
- **`ctx.run("start", info)`** calls `RunEvents.Changed(before, run, "replaced")`: an open run gets `end` with reason `replaced` first, as in the game. `ctx.run("end", info)` calls `RunEvents.Changed(run, nil, info.reason or "ended")`; the reason is `ended`, `replaced` or `deleted`, and there must be an open run. `info` defaults: `plan` "Test plan", `digest` "00000000", `runId` "ct-test-1". The callback runs as addon code; when it raises, `ctx.run` raises with its error (in game the error goes to CheckThat's error list).
- **`ctx.entry(name, ...)`** calls the entry the addon registered under its own name, as addon code, and returns its values. It returns nil when there is none, raises with the entry's error when it raises, and raises "in combat" in combat (an auto step's entry is refused in combat).
- **`ctx.reports()`** returns a copy of the fact lines of this load. With today's fake (hook steps in offline blocks) it returns the `Report` lines of this load too; `ctx.run` raises there ("needs ct test").
- **Budget.** `ctx.entry` and `ctx.run` call addon code under `H.budgeted`, as a handler is. The review found that `H.budgeted` read the global `jit`, which the runner hides from addon code, so a tight loop in a handler a step or hook fired could run on without `jit.off` and never reach the hook. The harness now reads `jit` and `debug` when it loads. This only turns a hang into the budget error that level 5 already promises.
- **Errors at registration.** `RunEvents.Register` sends `start` when a run is open, so after `ctx.reload()` the callback can raise outside `ctx.run`. The runner keeps a list of callback errors for each load; `ctx.reload` raises with them.
- **Load order.** The game loads addons by name unless dependencies say otherwise; CheckThat's TOC lists only BugGrabber, so an addon whose name sorts before CheckThat loads first ("late"), and an addon that names CheckThat in its dependencies, or sorts after, loads after it ("early"). In game CheckThat sets its global in AceAddon's `OnInitialize`, during its own `ADDON_LOADED`. Which frame gets that event first is not measured (#286), so `late` fires `ADDON_LOADED("CheckThat", containsBindings)` before `VARIABLES_LOADED` and sets the global after the addon's handlers: an addon that also looks at `PLAYER_LOGIN` works in either order. `missing` leaves it nil. `CheckThat` is left out of the nil-read report, since the test chose.

## Risks / Trade-offs

- CheckThat's modules now run inside `ct test`. They are data only and run with the host's globals; a change to them changes the fake too, which is the point.
- `Report` now drops facts outside a run, as in game. A test that reads facts calls `ctx.run("start")` first.
