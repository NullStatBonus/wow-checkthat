## Why

Issue #245: plans carry no "needs a runner of at least X" stamp. `Plan.Validate` requires `ct == 1` and ignores unknown keys, so an older CheckThat given a newer plan gives the wrong reason, or skips a new check and passes a step that should fail. This happened between 0.20 and 0.21. Only runners that know the key can honour it, so it must ship before 1.0.

## What Changes

- New optional top-level plan key `needs`: an integer plan revision. `Plan.REV` (CheckThat) and `PLAN_REV` (`ct.py`) are both 1, which is the format as of 0.21.0, and a test keeps them equal.
- CheckThat refuses a plan whose `needs` is above `Plan.REV` before any other check, with "This plan needs a newer CheckThat. It uses plan revision N, and this version reads up to M." Nothing is stored. A `needs` that is not a positive integer is invalid.
- `ct.py` keeps `PLAN_NEEDS`: one rule (revision, what, test) for each later addition. `compile` writes `needs` only when a rule matches or the plan gives one, so a revision 1 plan compiles to the same string and digest as before. `validate` fails a `needs` above `PLAN_REV` or below what the plan's keys require.
- Schema, plan-format spec and `docs/authoring-plans.md`.

## Capabilities

### Modified Capabilities
- `test-plan-format`: a plan may declare the revision it needs.

## Impact

`CheckThat/Model/Plan.lua`, `CheckThat/Model/App.lua` (import message), `tools/ct.py`, `schema/test-plan.schema.json`, tests, docs.

Compatibility is additive. A plan without `needs` behaves as before. A runner from before this change ignores `needs`, so the benefit starts with the first version that ships it.

The version bump is held, per the release hold. The next bump carries this change in its changelog.
