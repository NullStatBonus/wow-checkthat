# Tasks

## 1. Open asks

- [x] 1.1 Add `App.OpenAsks(id)` and the second question text; Open run uses them. Verify: `tests/test_app.lua`, `tests/test_options.lua`.
- [x] 1.2 Log `run open asked` and `run delete asked` from the confirm functions, `run exported` from `App.Export`, `report requested` from the report. Verify: tests for each line.

## 2. Run button

- [x] 2.1 Release and register the state driver in `setMacro`. Verify: `tests/test_smoke.lua`.
- [x] 2.2 Break each change, see its test fail, restore.

## 3. Docs and plan

- [x] 3.1 README, `docs/test-plan.md`, `CHANGELOG.md` 0.8.0, `docs/contracts.md`, plan assertions for the new lines. Verify: `make test`, `make check`.

## Workflow follow-up

- 0.8.0 is not released, so it keeps its number. The PR closes #46 and #47.
