# Proposal

## Why

`skills/ct-test-plan/SKILL.md` mixed the rules for any addon with CheckThat internals (`Plan.SLASH`, `LOGS` in `ct.py`, the `/ct version` fact recipe), so an author of another addon met those first (#132).

## What Changes

- `SKILL.md` keeps the general flow and points to `reference.md` for the three CheckThat details.
- `reference.md` gains "CheckThat specifics": supported addons, log sources, the version check recipes (CheckThat, an integrating addon, any other addon).

## Capabilities

### Modified Capabilities

- `test-plan-authoring`: the skill's main text is addon-neutral.

## Impact

- `skills/ct-test-plan/SKILL.md`, `skills/ct-test-plan/reference.md`, `tools/test_ct.py`.
- Skill text only. No file under `CheckThat/` changes, so no version bump.
