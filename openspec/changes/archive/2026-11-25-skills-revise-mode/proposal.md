# Proposal

## Why

After `ct-verify` reports, authors rerun by hand and cannot tell a plan fault from an addon fault (#131). A plan fault wastes a tester's run: the 0.17 plan took five in-game runs, most of them plan mechanics.

## What Changes

- `ct-test-plan` gains a "Revise after a run" section: read the verify report with its version warnings, sort each failing step into plan fault, addon fault or unknown, edit only plan faults with stable ids, run the handoff gate again, and say whether the next run is `/ct rerun failed` (plan unchanged) or a new import (plan changed), then compare with `ct.py diff`.
- `ct-verify` points to that section when a step failed for a plan reason. It still never edits a plan.

## Capabilities

### Modified Capabilities

- `test-plan-authoring`: the revise section.

## Impact

- `skills/ct-test-plan/SKILL.md`, `skills/ct-verify/SKILL.md`, `docs/skills.md`, `tools/test_ct.py`.
- Skill text and docs only. No file under `CheckThat/` changes, so no version bump.
