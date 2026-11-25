# Proposal

## Why

A tester ran the 0.17 plan against a copy of 0.16.0 that the deploy script put in the game. The run produced twelve failures that meant nothing. A plan has no way to check the version it tests.

## What Changes

- New command `/ct version` prints the CheckThat version. With a run open it also reports the fact `version` as `major*10000 + minor*100 + patch`, so a plan can check "this version or newer" with `op: ge`.
- Every plan starts with a version check (skill rule). `plans/checkthat-0.17.yaml` gets that step.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-runner-ux`: the `/ct version` command.

## Impact

- `CheckThat/Core/Slash.lua`, `tests/test_slash.lua`, `README.md`, `docs/features.md`, `skills/ct-test-plan/SKILL.md` and `reference.md`, `plans/checkthat-0.17.yaml`.
- Addon code changes. The version stays 0.17.0: that release is not tagged yet and this change joins the same pull request.
