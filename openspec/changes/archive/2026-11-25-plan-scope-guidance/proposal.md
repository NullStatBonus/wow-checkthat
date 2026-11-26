## Why

A one-for-one conversion of a manual test document grew to 507 steps (#162). Most re-checked logic the unit tests already prove, and nothing in `validate` or the skill pushed back on the size. A plan written for the default settings also fails for a tester who changed them, and its setting commands overwrite the tester's own settings (#167).

## What Changes

- `ct.py validate` (and `from-md`) warns, without failing, when a plan has more than 25 steps or a section more than 10. Each case counts as a step.
- The `ct-test-plan` skill scopes before it drafts or converts: a plan checks only what a fake game cannot prove, coverage is measured, the essential draft comes first, and a larger scope becomes a plan set by area.
- The skill asks whether the plan depends on the addon's settings and, if so, recommends a test-settings mode in the addon with a fixed setup and teardown step pattern.
- `docs/authoring-plans.md` gains "Keep a plan short", "Plan sets" and "Test settings"; `docs/skills.md` and the skill's checklist follow.

## Capabilities

### New Capabilities

### Modified Capabilities

- `test-plan-format`: validation warns about a long plan or section.
- `test-plan-authoring`: the skill scopes a plan to what a fake game cannot prove, splits a large scope into a plan set and recommends a test-settings mode.

## Impact

Tools, skill and docs only. No file under `CheckThat/` changes, so no version bump. The warning is a new output line; exit codes and existing output are unchanged.
