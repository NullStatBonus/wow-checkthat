# Design

## Context

`tools/entry_runner.lua` already loads an addon's TOC into the fake client per client surface (level 5), with the game's load order (level 3), the event list and virtual clock (level 4), taint latching (level 6), hidden globals, mocks and the nil-read report. Level 5 hook steps call the developer's Lua with `ctx`, the first public fake-client API. `tests/harness.lua` is CheckThat's own test helper and stays internal.

## Goals / Non-Goals

**Goals:**
- A developer with only the installed bundle writes `tests/test_x.lua`, runs it against the Era and Forever surfaces with one command, and finds every helper they use documented and stable.
- One public surface: a test gets the same `ctx` as a hook step.

**Non-Goals:**
- Publishing `tests/harness.lua` (`H`, `T`) as a library. Its helpers serve CheckThat's suite, change with it, and expose internals (frame stubs, taint state). `ctx` covers what a developer test needs and is already promised as additive. Issue #273's step 3 (harness as a wrapper over a public module) is therefore not done: the public module is `ctx` in the runner, and CheckThat's suite exercises it through `tests/test_entries.lua` and `tools/test_ct.py`.
- JUnit or JSON output for `ct test`. The text and exit code serve a terminal and CI; a format can be added later.
- Modelling clients other than Era and Forever: a TOC for another interface range is left out.

## Decisions

- **Each test is a run of `Runner.run` with one hook step.** The test function is handed in as `opts.hooks` (a table, never from a plan), at level `Runner.LEVEL`. So every load check, mock rule, hidden global and nil-read rule of the offline runner applies unchanged, and a test failure reads like a hook failure. A plan's offline block still loads hooks only from its `hooks` file.
- **One process for each test file and client.** `ct.py` runs `tools/addon_test.lua JOB.json` once per pair, as `tests/run.lua` does for CheckThat's own files, so a file cannot leak globals into another. Inside a file each test gets a fresh load; level 3 and up put the global table back after each run.
- **The TOC for a client** comes from the `## Interface:` numbers of each `*.toc` in the folder (a comma list counts for each number, and the runner gets that number through `opts.interface`, never a plan key). When two TOCs claim one client, the suffix the client reads wins, then any suffix, then the plain name. The addon's name comes from the TOC names (`opts.addonName`), so a checkout folder named otherwise loads as the game would.
- **The result goes to a file** named in the job, so a test file's `print` at load or `io.write` cannot corrupt it; `ct test` shows that output under the file's lines. Each process has a 300-second limit.
- **The tests folder is test code**: its nil reads are skipped (`opts.testDir`), `require` looks there, and the process runs from the addon's folder.
- **`asAddon` is re-entrant**: a handler that calls `ctx.fire` runs it as addon code. `ctx.reload` from a handler raises a clear error, as reloading the load a handler belongs to has no game equivalent.
- **`ctx.reload()`** runs the same code as a `reload` step (logout events in the measured order, saved variables copied, a fresh load with `reloading` true), through `asAddon` so the addon sees its own globals. It raises with the step's error text when it fails, and updates `ctx.ns`.
- **The test file's own nil reads** stay out of the report, as a hooks file's do.

## Risks / Trade-offs

- A test can change anything in the fake client, so its pass proves what it checks. Same as a hook.
- `ct test` runs the addon's Lua and the test file with the user's permissions, as `ct offline` does; the help says so.
