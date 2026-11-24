# Proposal

## Why

Rerunning a category with one finished step asks "This reopens 1 completed steps" and says "Reopened 1 steps" (issue #75). After a run with failures in several categories, the tester must find and rerun each one by hand (issue #69).

## What Changes

- The rerun question and the reopen message use the singular for one step.
- `/ct rerun failed` and a row menu item in the Categories window reopen every failed or unverified step in every picked category, after asking.
- `failed` becomes a reserved id: validation rejects it as a category id, and as a section id when the plan declares no categories.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-categories`: rerun failed steps.
- `test-plan-format`: the reserved id.
- `slash-interface`: the rerun command takes `failed`.

## Impact

- Code: `CheckThat/Model/Run.lua`, `App.lua`, `Plan.lua`, `CheckThat/Core/Slash.lua`, `CheckThat/UI/Card.lua`, `Tracker.lua`, `tools/ct.py`, `schema/test-plan.schema.json`. Docs and tests follow.
- Version 0.11.0 (new capability).
