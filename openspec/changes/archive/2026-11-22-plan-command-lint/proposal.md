# Proposal

## Why

A step whose text names an allowed slash command but lists no `commands` shows no copy box or Run button, so the player must type the command by hand. Authors find this only by reading plans (issue #12). The check exists today only as a test helper for the skill's example plan.

## What Changes

- `tools/wtt.py validate` prints a `warning:` line for each allowed slash command that step text names (colored or plain) but the step's `commands` lacks. Warnings do not change the exit code.
- `from-md` prints the same warnings for its draft.
- Move the existing test-only check into `tools/wtt.py` so tool, skill and tests share one rule.
- Fix any shipped plan the new warning flags.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-format`: validation reports allowed slash commands named in step text but missing from `commands`.

## Impact

- `tools/wtt.py`, `tools/test_wtt.py`, `plans/**/*.yaml` (only if flagged).
- `openspec/specs/test-plan-format/spec.md`. No schema, addon or saved-data change.
