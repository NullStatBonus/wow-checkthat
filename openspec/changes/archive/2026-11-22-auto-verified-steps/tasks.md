# Tasks

Each behavior gets a test first. Break the behavior on purpose, check the test fails for the expected reason, restore it, check it passes.

## 1. Plan fields and validation

- [x] 1.1 Add `auto` and `timeout` to `Plan.Validate` in `TestThat/Model/Plan.lua`: auto needs `assertions` and no `player` in `verify`, at least one required assertion and no required absence assertion; timeout is an integer 5 to 300 and only on an auto step; `wait-event` only on an auto step. Verify with new cases in `tests/test_plan.lua` for every scenario in the `test-plan-format` delta.
- [x] 1.2 Mirror the fields and rules in `schema/test-plan.schema.json` and `tools/wtt.py` (compile, validate). Verify with `tools/test_wtt.py` cases and `make test`.
- [x] 1.3 Keep the plan format spec in step: `openspec/specs/test-plan-format/` is updated at archive from the delta. Verify the schema and `Plan.Validate` accept and reject the same sample plans.

## 2. Automatic settle in the model

- [x] 2.1 Add an optional `by` argument to `Run.Verdict` in `TestThat/Model/Run.lua` that stores `by = "auto"` on the attempt (`claimed` keeps the pass claim). Verify in `tests/test_run.lua` that a player pass is unchanged and an auto pass carries the label.
- [x] 2.2 Add `Run.AutoSettle(run, ctx, id)`: settle with a pass claim when every required assertion is met; at the timeout settle through the same gate; skip a step whose last attempt was settled by auto with no later player action; do nothing when the step is not auto, not open, or already has a player verdict. Verify in `tests/test_run.lua` with a fake clock and log for each scenario in the `run-evidence` delta: line appears, not all met, player clicks first, undo, contradiction at timeout, missing evidence at timeout, recovery before timeout, reload keeps the clock, no loop of attempts.
- [x] 2.3 Assert that an automatic settle makes no protected or input call on the fake client. Verify the test fails if `AutoSettle` calls an Adapter input function, then restore it.
- [x] 2.4 Log the result in `App` as "step <id> <verdict> auto ..." and carry `by` into `Run.Export`. Verify in `tests/test_app.lua` and `tests/test_interop.lua` that the log line and the results string show it.

## 3. Card

- [x] 3.1 Call the auto check from `Card.UpdateChecks` in `TestThat/UI/Card.lua` and refresh the card after a settle, with errors logged and never allowed to leave the step stuck. Verify with the fake client in `tests/test_smoke.lua` (or a new card test using `tests/harness.lua`) that a log line moves the card on without a button press and a hidden card records nothing.
- [x] 3.2 Show "TestThat records the result when the checks are met", the seconds left, the `wait-event` wording, and the "recorded by TestThat" mark on a settled step. Every sentence is `L["..."]`. Verify `tests/test_locale.lua` passes and the card text tests cover the countdown.
- [x] 3.3 Open the self-test plan `plans/selftest.yaml` with one auto step and one auto step with a timeout. Verify `tests/test_selftest.lua` and `make build` pass.

## 4. Report, docs and skill

- [x] 4.1 Show the auto mark in the report from `tools/wtt.py`. Verify with a `tools/test_wtt.py` fixture using anonymized data.
- [x] 4.2 Update `README.md` (auto steps, timeout, what hidden cards do, the `/wtt log` line), `docs/listing.md` and its summary if the headline changes, and `docs/test-plan.md` with short manual checks (one player action, a `Check:` line in player words, the proof on a `Log:` line). Verify `tests/test_readme.lua` passes and section numbers stay unique and in order.
- [x] 4.3 Update the plan-authoring skill (`skills/wtt-test-plan/SKILL.md`): when a step may be auto, how to pick a timeout, and the rule that judgment steps stay manual. Verify with a dry read of the skill against the `test-plan-authoring` delta scenarios.
- [x] 4.4 No new probe or client fact was measured, so `docs/contracts.md` is unchanged.

## 5. Integration

- [x] 5.1 Run `make test` and `make check`; fix failures. Verify both exit 0.
- [ ] 5.2 Build `build/selftest.wtt`, import in game, and check one auto step passes by itself and one fails at its timeout. Read `/wtt log` or the saved variables to confirm; do not ask the player to read a log line.

## Workflow follow-up

- At archive: sync the deltas, bump both TOC versions to the next minor (new capability) and add the matching `CHANGELOG.md` section, then commit with the version in the message.
- Comment on #24 that polling covers the trigger and event registration is what remains. Close #6 and #23 with the change. #27 stays open.
