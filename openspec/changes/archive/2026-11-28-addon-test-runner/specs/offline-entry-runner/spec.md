## ADDED Requirements

### Requirement: ct test runs the developer's own tests
`ct test [folder]` SHALL run each `<folder>/tests/test_*.lua`, in name order, once for each client the folder has a TOC for, each file and client in its own process, at the runner's newest level. The client of a TOC SHALL come from its `## Interface:` numbers (10000 to 15999 Era, 16000 to 19999 Forever, any other left out), and each client SHALL run with its own number. When two TOCs claim a client, the suffix that client reads (`_Vanilla` or `_Classic`, `_Camelot`) SHALL win, then any other suffix, then the plain name, then the first by name. The addon's name SHALL be the folder's when a TOC is named after it, else the name the TOC files share. Each process SHALL write its result apart from what the test file writes, which the command SHALL show under the file's lines; a process that runs longer than 300 seconds SHALL be stopped and fail. Nil reads of any file in the addon's `tests/` folder SHALL NOT be in the report, and `require` SHALL find files there. A test file SHALL get `ct` as its `...`, with `ct.test(name, [options,] fn)` and `ct.API` (1). Each test SHALL get a fresh load of the addon with `options.mocks` and `options.savedVariables` (the offline block's shapes) and SHALL call `fn(ctx)` with the hook context; it passes when `fn` returns and fails with the error text when it raises or the load fails. The command SHALL print one line for each test and client, the nil-read report for each client, and a summary, and SHALL exit 1 when a test fails and 2 when the folder has no TOC, no test file, or no test matches `--name`. `--client` SHALL narrow the run to one client and fail when the folder has no TOC for it.

#### Scenario: Both clients
- **WHEN** a folder has `MyAddon_Vanilla.toc` (11507) and `MyAddon_Camelot.toc` (16001) and one test
- **THEN** `ct test` runs the test twice, once with each TOC, and prints a line for `era` and one for `forever`

#### Scenario: A failing test
- **WHEN** a test calls `ctx.eq(ctx.ns.count, 2, "count")` and the addon set 1
- **THEN** its line says FAIL with "count: expected 2, got 1" and the command exits 1

#### Scenario: A file that raises at load
- **WHEN** a test file raises before it registers a test
- **THEN** the file fails for that client with the error text, and the other files still run

## MODIFIED Requirements

### Requirement: The hook context is a public API
Each hook SHALL get a `ctx` with `ns` (the addon's private namespace of the current load), `client` (`era` or `forever`), `level`, `fire(event, ...)` (returns the number of frames, raises when a handler raises or when the event fails the level 4 event check), `combat(on)` (enters or leaves combat as the fake client models it), `advance(seconds)` (moves the virtual clock and runs the timers due, raises when one raises), `mockCalls(api)` (the count for this group), `eq(got, want, what)` and `same(got, want, what)` (deep, cycle-safe, naming the first differing path), `ok(value, what)` (raises when value is false or nil), `raises(fn, text, what)` (raises unless fn raises an error that contains the plain text) and `reload()` (the game's reload as a `reload` step does it, called from the hook or test itself and not from a handler it fires; `ctx.ns` then names the new load's namespace; raises with the step's error text when it fails). A `ct test` test SHALL get the same `ctx`. Fields SHALL only be added, never removed or changed in meaning.

#### Scenario: Combat and the clock from a hook
- **WHEN** a hook calls `ctx.combat(true)`, then `ctx.advance(2)`
- **THEN** `InCombatLockdown()` is true in the addon's timer callback that comes due

#### Scenario: A reload from a test
- **WHEN** a test sets a saved variable through the addon, then calls `ctx.reload()`
- **THEN** the addon's new load reads the value, and `ctx.ns` is the new namespace
