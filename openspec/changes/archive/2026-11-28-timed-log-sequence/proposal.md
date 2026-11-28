# Proposal

## Why

Issue #59: a step cannot say "line B within 2 seconds of line A". Debug lines carry no time in a plan check, so `log-sequence` proves order only, and an auto step's `timeout` bounds the whole step. A plan that needs a fast reaction (a vendor that sells at once, a warning that follows an action) has no way to prove it, and a plan that checks it with an earlier line reads weaker evidence.

## What Changes

- An item of a `log-sequence` after the first MAY give `within`: the whole seconds, 1 to 600, within which its line must be written after the line of the item before it.
- `Evidence.CheckSequence` reads each line's time when an item gives `within` and chains the matches so an early line that leaves too little time is swapped for a later line of the same item. The match is unverified, never failed, when a gap is too long, a line did not come, or the log keeps no time for the window.
- `Evidence.NewLines` also returns the index of the first new line, so the times of a step's window line up with its lines.
- `CheckThat/Model/Plan.lua`, `schema/test-plan.schema.json` and `tools/ct.py` gain the field and its validation. The schema types it; both validators refuse it on the first item, as they refuse a bad `id` or `bag` of a state probe.
- Plan revision 3: `Plan.REV`, `PLAN_REV` and `PLAN_NEEDS` in `tools/ct.py`, so `compile` writes `needs: 3` and a reader of revision 2 refuses the plan instead of skipping the gap.

## Capabilities

### Modified Capabilities
- `test-plan-format`: the `within` field of a sequence item, its validation, and how a gap that does not hold reads.

## Impact

`CheckThat/Model/Evidence.lua`, `CheckThat/Model/Plan.lua`, `schema/test-plan.schema.json`, `tools/ct.py`, `tests/test_sequence_time.lua`, `tests/test_plan.lua`, `tools/test_ct.py`, `README.md`, `docs/authoring-plans.md`, `docs/features.md`, `docs/test-plan.md`, both TOC files, `CHANGELOG.md`. Additive: no plan, saved variable or results key changes. A plan that does not give `within` keeps revision 1 or 2 and reads the same.
