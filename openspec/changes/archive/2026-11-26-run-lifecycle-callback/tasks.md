## 1. Registry and API

- [x] 1.1 Add `Model/RunEvents.lua` with register, notify and active-run lookup, and list it in both TOC files in the same order. Verify with `luajit tests/test_runcallback.lua` and `make check`.
- [x] 1.2 Expose `OnRun` and `ActiveRun` in `Facts.API()` and set `API_VERSION` to 3. Verify in `tests/test_entry_api.lua`: valid, invalid and never-raises cases.

## 2. Fire the events

- [x] 2.1 In `App.End`, `App.Start`, `App.OpenRun` and `App.DeleteRun`, fire `end` and `start` from the open run before and after. Verify with the scenarios in `specs/run-lifecycle/spec.md`: ended, replaced, deleted, reload, other addon, order.
- [x] 2.2 Fire `start` once when an addon registers with a run open. Verify with the late-registration scenario.
- [x] 2.3 Call with `pcall`, pass a copy of `info`, record a raised error and log each call. Verify with a throwing callback: the run still ends and the error is listed.
- [x] 2.4 Break each firing point in turn and confirm its test fails, then restore it.

## 3. Docs and checks

- [x] 3.1 Update `docs/features.md` (with debug lines), `docs/contracts.md` (API table), `README.md` and `docs/listing.md`. Verify with `make test` (`tests/test_readme.lua` and `tools/test_ct.py`).
- [x] 3.2 Add one manual check to `docs/test-plan.md`, with a `Check:` line and a `Log:` line. Keep section numbers in order.
- [x] 3.3 Run `make test` and `make check`. Do not change the TOC versions or `CHANGELOG.md`.

## Workflow follow-up
- Archive the change with the archive skill, without a version bump.
- Close #171 in the commit message.
