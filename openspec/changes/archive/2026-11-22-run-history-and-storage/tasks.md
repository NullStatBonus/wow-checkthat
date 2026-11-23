# Tasks

## 1. Smaller snapshots

- [x] 1.1 `Evidence.Snapshot(plan, env, step)` records `{ n, tail }` for the sources of the step's attempt-scoped log assertions only; `Run.Begin` passes the step. Verify: `luajit tests/test_evidence.lua` and `tests/test_run.lua` cover recorded sources, none for session scope, and no entry for an unchecked log.
- [x] 1.2 `NewLines` accepts the position record and the old full array. Verify: test with both shapes, rolled and unrolled logs.
- [x] 1.3 `CheckLog` and `CheckSequence` give unverified when the source has no position. Verify: test that a matching line without a position does not pass.
- [x] 1.4 Break each behavior in turn (snapshot all sources; drop the missing-position guard), see its test fail, restore.

## 2. Plan and run pruning

- [x] 2.1 `App.PrunePlans()` called from `ImportPlan`, `ClearPlan` and run delete. Verify: `tests/test_app.lua` for an orphan revision, a plan kept by a run, by a loaded plan and by a recent entry.
- [x] 2.2 Run limit setting (default 20, 5 to 100) in settings defaults, enforced in `App.Start` and `App.DeleteRun`, never removing a character's current run. Verify: `tests/test_app.lua` and `tests/test_settings.lua`.
- [x] 2.3 `App.Runs()`, `App.OpenRun(id)`, `App.DeleteRun(id)`. Verify: `tests/test_app.lua`, including deleting the current run.

## 3. Runs list on Home

- [x] 3.1 Runs group on the Home page with Open, Export, Delete (confirm) per row, hidden when empty. Verify: `tests/test_options.lua` (AceConfig validator passes) and a test that rows match `App.Runs()`.
- [x] 3.2 Run limit control on Advanced and its value plus stored run and plan counts in the debug report. Verify: `tests/test_options.lua` and `tests/test_log.lua`.
- [x] 3.3 Strings use `L["..."]`. Verify: `luajit tests/test_locale.lua`.

## 4. Docs and release

- [x] 4.1 Update README (Home page, run limit setting, Good to know), `docs/listing.md`, and `docs/test-plan.md` with short manual checks: reopen an ended run, export an old run, delete a run. Verify: `luajit tests/test_readme.lua`.
- [x] 4.2 `make test` and `make check` pass.

## Workflow follow-up

- Bump minor version in both TOC files, write the CHANGELOG section and tag at archive (addon code changed).
- Close issues #2 and #5 when released.
