# Tasks

## 1. Shared check

- [x] 1.1 Add `warnings(plan)` to `tools/wtt.py` (move logic from `PlanSkill.missing_commands`); point the skill test at it. Verify `python3 tools/test_wtt.py` passes.
- [x] 1.2 Print `warning: <step>: command named in text but not in commands: <cmd>` from `validate` and `from-md`; exit code unchanged. Add a CLI test for a warned plan (exit 0, warning printed). Break the check, confirm the test fails, restore.

## 2. Plans and docs

- [x] 2.1 Run `validate` on every file in `plans/` and `plans/full/`; fix flagged steps; extend `test_shipped_plans_validate` to assert no warnings. Verify `make test` passes.
- [x] 2.2 Document the warning in `skills/wtt-test-plan` guidance and `openspec/specs/test-plan-format` (via sync). Verify `make check` passes. No README, listing or test-plan change: no player-visible behavior changes.

## Workflow follow-up

- Archive the change (version bump, CHANGELOG entry) before commit; close issue #12.
