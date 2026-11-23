# Proposal

## Why

The card already lists each required check live and says "All checks detected. Press Pass." For a step whose evidence is a log line or a state probe, that click adds nothing, and an expected failure is just as mechanical. Test frameworks such as WoWUnit settle a test from its asserts alone. TestThat can do the same without breaking its rule of no input automation, because recording a verdict only reads logs and state the addon already reads. Nothing is clicked, typed, cast or run. Issues #23, #24 and #6 all ask for part of this.

## What Changes

- A step MAY set `auto: true`. While the card is shown and the step is open, the runner re-reads the required assertions on the card's existing half-second refresh. When every required assertion is met, it records a pass by itself and moves on.
- An auto step MAY also set `timeout` (seconds, counted from when the attempt opens). When the timeout passes with checks not all met, the runner settles the step through the existing evidence gate: a contradicted check records fail, missing evidence records unverified.
- An auto step is allowed only when its evidence can settle it alone: `verify` is assertions without `player`, it has at least one required assertion, and none of them is an absence check.
- The `wait-event` action kind gets its meaning: it marks a step the player completes by doing something in game, and the card shows what the runner is waiting for. It is valid only on an auto step. This closes #6.
- The attempt records that the runner settled it (`by = "auto"` on the attempt). The card, the debug log, the results string and the report show it, so a reviewer can tell it from a player click. A player click on Pass, Fail, Partial or Skip still works and wins if it comes first. Undo and Redo work as before.
- The step stays open after an automatic unverified result. It does not start new attempts by itself, so no loop of unverified attempts builds up.
- Plan validation, the JSON schema, `tools/wtt.py`, the README, the listing text, the test plan and the plan-authoring skill describe the new fields.

No new setting, slash command or game call is added.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `test-plan-format`: `auto` and `timeout` step fields with their validation rules; `wait-event` limited to auto steps.
- `run-evidence`: the runner records a verdict by itself from the evidence gate; the claim is labelled `auto`; timeout settles through the same gate; one automatic settle per attempt.
- `test-runner-ux`: auto-verification stays read-only and starts no game action; the card shows that the step passes by itself, the time left, and the wait-event wording; the banner says who checks the step.
- `test-plan-authoring`: the authoring skill guides when to mark a step auto and how to choose a timeout.

## Impact

- Code: `TestThat/Model/Run.lua` (auto settle, `claimed = "auto"`), `TestThat/Model/Plan.lua` and `schema/test-plan.schema.json` (fields, rules), `TestThat/Model/App.lua` (log line), `TestThat/UI/Card.lua` (tick calls the auto check; step wording), `tools/wtt.py` (compile, report label), `.claude/skills/wtt-test-plan`.
- Docs: README, `docs/listing.md`, `docs/test-plan.md`, `docs/contracts.md` if a probe is added, plan format specs.
- Tests: new cases in `tests/test_run.lua`, `tests/test_plan.lua`, `tests/test_card.lua` (or the nearest existing files) and `tools/test_*.py`.
- Addon code changes, so the version rises at archive. This is a new player-visible capability.
- Related issues: #6 (closed by this change), #23 (closed), #24 (reduced to event-driven triggers; stays open), #13 (supplies sample steps with required assertions).
