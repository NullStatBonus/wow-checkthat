# Proposal

## Why

Nothing tells a plan author which slash subcommands, settings or documented requirements no plan step touches. The coverage table in the plan skill covers only the current change and is filled in by hand. (Issue #93.)

## What Changes

- New command `ct.py coverage <plan...> --addon-src <path>` lists each subcommand and setting key of the addon as used or unused, with the ids of the steps that cover it.
- A step or section may carry `covers: [requirement name]`. The name is a `### Requirement:` heading of the addon's `openspec/specs/*/spec.md`. The report lists requirements no step covers. A name that matches no heading is a validation error. The compiler drops the field, so the compiled string does not change.
- `--evidence` joins the latest finished run of each plan: covered and passed, covered but failed or unverified, never run.
- The spec says what the code does: tools reject unknown plan fields, the game ignores them. A game-side test shows the game ignores `covers`.

## Capabilities

### New Capabilities
- `plan-coverage`: the coverage report.

### Modified Capabilities
- `test-plan-format`: the `covers` field, and the unknown-field rule.

## Impact

- `tools/ct.py`, `tools/test_ct.py`, `schema/test-plan.schema.json`, `tests/test_plan.lua`, `tests/fixtures/coverage/`.
- README, `docs/authoring-plans.md`, `docs/harvesting.md`, `docs/skills.md`, `skills/ct-test-plan/SKILL.md`.
- No file under `CheckThat/` changes, so the addon version stays.
