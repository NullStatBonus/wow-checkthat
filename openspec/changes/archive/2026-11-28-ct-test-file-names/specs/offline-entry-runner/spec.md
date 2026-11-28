## MODIFIED Requirements

### Requirement: ct test runs the developer's own tests
`ct test [folder]` SHALL run each `test_*.lua` and `*_test.lua` in `<folder>/tests` whose text names `ct.test`, in name order, once for each client the folder has a TOC for, each file and client in its own process, at the runner's newest level. The client of a TOC SHALL come from its `## Interface:` numbers (10000 to 15999 Era, 16000 to 19999 Forever, any other left out), and each client SHALL run with its own number. When two TOCs claim a client, the suffix that client reads (`_Vanilla` or `_Classic`, `_Camelot`) SHALL win, then any other suffix, then the plain name, then the first by name. The addon's name SHALL be the folder's when a TOC is named after it, else the name the TOC files share. Each process SHALL write its result apart from what the test file writes, which the command SHALL show under the file's lines; a process that runs longer than 300 seconds SHALL be stopped and fail. Nil reads of any file in the addon's `tests/` folder SHALL NOT be in the report, and `require` SHALL find files there. A test file SHALL get `ct` as its `...`, with `ct.test(name, [options,] fn)` and `ct.API` (1). Each test SHALL get a fresh load of the addon with `options.mocks` and `options.savedVariables` (the offline block's shapes) and SHALL call `fn(ctx)` with the hook context; it passes when `fn` returns and fails with the error text when it raises or the load fails. The global `CheckThat` SHALL be CheckThat's own public table (`Facts.API()`, built from CheckThat's `Facts`, `Entries` and `RunEvents` for each load, with `Commands` checked by CheckThat's `Plan` rules), so `Report` records only while a run is open. `options.checkThat` SHALL set when it loads: `early` (default, before the addon's first file), `late` (nil while the addon's files run and at its `ADDON_LOADED`; then `ADDON_LOADED("CheckThat", containsBindings)` fires before `VARIABLES_LOADED`, `containsBindings` true when `CheckThat/Bindings.xml` exists, and the global is set after the addon's handlers for it) or `missing`; any other value fails the file. `ctx.run("start", info)` SHALL open a run for the addon (`info.plan`, `digest`, `runId`, `addon`, with defaults) and `ctx.run("end", info)` end it (`reason` `ended`, `replaced` or `deleted`), through CheckThat's `RunEvents`: `OnRun` gets the event, `ActiveRun` answers, a `start` while a run is open sends `end` with `replaced` first, the run stays open across `ctx.reload()` and `start` comes again when the addon registers, and `ctx.run` raises when the callback raises, when `end` finds no open run, or for an unknown event or reason; `ctx.reload()` raises when the callback raises at the new load's `start`. An entry or callback that `ctx.entry` or `ctx.run` calls SHALL run under the handler's script-time budget. `CheckThat` SHALL NOT be in the nil-read report of a `ct test` run. An offline block SHALL keep its older fake CheckThat. The command SHALL print one line for each test and client, the nil-read report for each client, and a summary, and SHALL exit 1 when a test fails and 2 when the folder has no TOC, no test file, or no test matches `--name`. A matching file whose text never names `ct.test` SHALL be skipped and listed after the nil-read report; when every matching file is skipped the command SHALL exit 2 and say they are for another runner. `--client` SHALL narrow the run to one client and fail when the folder has no TOC for it. `--tests DIR` SHALL look in `DIR` in place of `<folder>/tests`, `require` SHALL find files in `DIR`, and the command SHALL exit 2 when `DIR` is not a folder or holds no such file.

#### Scenario: Both clients
- **WHEN** a folder has `MyAddon_Vanilla.toc` (11507) and `MyAddon_Camelot.toc` (16001) and one test
- **THEN** `ct test` runs the test twice, once with each TOC, and prints a line for `era` and one for `forever`

#### Scenario: A failing test
- **WHEN** a test calls `ctx.eq(ctx.ns.count, 2, "count")` and the addon set 1
- **THEN** its line says FAIL with "count: expected 2, got 1" and the command exits 1

#### Scenario: A file that raises at load
- **WHEN** a test file raises before it registers a test
- **THEN** the file fails for that client with the error text, and the other files still run

#### Scenario: Tests outside the addon folder
- **WHEN** a repo keeps `MyAddon/` and its tests in `tests/ct/test_bags.lua`, and runs `ct test MyAddon --tests tests/ct`
- **THEN** `ct test` runs `test_bags.lua` and not `MyAddon/tests/test_*.lua`, and a `--tests` folder that is missing or has no `test_*.lua` exits 2

#### Scenario: A run from a test
- **WHEN** an addon's `OnRun` function sets test mode at `start` and clears it at `end`, and a test calls `ctx.run("start", { plan = "Bags" })`, then `ctx.run("end")`
- **THEN** test mode is on, `CheckThat.ActiveRun` returns "Bags", then test mode is off, and the callback got `start` and `end` with reason `ended`

#### Scenario: CheckThat loads after the addon
- **WHEN** a test has `checkThat = "late"` and the addon looks for `CheckThat` at `ADDON_LOADED` for `"CheckThat"` and at `PLAYER_LOGIN`
- **THEN** `CheckThat` is nil while the addon's files run, at its own `ADDON_LOADED` and in its handler for CheckThat's, and the addon finds it at `PLAYER_LOGIN`

#### Scenario: Tests next to another runner's
- **WHEN** `tests/` holds `bags_test.lua`, which calls `ct.test`, and `merchant_test.lua`, which the addon's own harness runs
- **THEN** `ct test` runs `bags_test.lua`, does not run `merchant_test.lua`, and prints "skipped 1 file(s) that do not call ct.test: tests/merchant_test.lua"
