## 1. Addon

- [x] 1.1 `Evidence.Snapshot` takes a scope filter; `Run.New` saves `run.snapshots` for `run`-scoped assertions; raise `Run.FORMAT_REV` to 5
- [x] 1.2 `window()` and every `scope ~= "session"` test handle `run` with the run's positions; a missing position is unverified
- [x] 1.3 `Plan.lua` accepts `scope: run`
- [x] 1.4 Lua tests: error in an earlier step fails, old error passes, reload keeps the position, old run is unverified, bad scope rejected (break each, watch it fail, restore)

## 2. Tools

- [x] 2.1 Schema enum, `ct validate`, report and show labels, `CHECK_STRINGS` check
- [x] 2.2 `tests/replay_plan.lua` handles `run`
- [x] 2.3 Python tests for validate and report

## 3. Docs and skill

- [x] 3.1 `docs/authoring-plans.md`, `docs/results-format.md` (revision 5 row), `docs/test-plan.md` manual check for the run scope
- [x] 3.2 Skill text and examples use `scope: run` for the final error step; drop the #161 notes
- [x] 3.3 `CHANGELOG.md` 0.21.0: add the OnRun line (#171) and the run-scope line
- [x] 3.4 `make test` and `make check`
