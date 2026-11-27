## Why

Issue #247: `cleanup` is a step key in the plan format, and the plan skill recommends it, but the addon never showed it. An author wrote cleanup text and the tester never saw it. The plan format freezes at 1.0, so the key is either shown or deprecated now. It is shown.

## What Changes

- After a step has a result (pass, partial, fail or skip), the card shows its `cleanup` in amber: "Then: <cleanup>" under a held result, and "First, after the last step: <cleanup>" at the top of the next step, until that step has a result.
- `ui.cleanup` (`{ run, step }`) keeps it across a reload. Undo or Redo of that step hides it. Debug log: `cleanup of <step id> shown next`.
- `ct.py`: `cleanup` is display text, so `from-md` converts its Markdown. `validate` warns about Markdown in it rather than failing, so a plan that validated before still does.
- The self-test's "Record a Lua error" step gets a cleanup (close the game's error window), and the shipped self-test is rebuilt.
- Docs: `authoring-plans.md`, `features.md`, `test-plan.md` (3.25).

## Capabilities

### Modified Capabilities
- `test-runner-ux`: the card shows a step's cleanup.

## Impact

`CheckThat/Model/App.lua`, `CheckThat/UI/Card.lua`, `CheckThat/Model/BuiltIn.lua`, `plans/selftest.yaml`, `tools/ct.py`, tests, docs. The plan format is unchanged. The version bump is held per the release hold.
