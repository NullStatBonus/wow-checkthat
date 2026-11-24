# Proposal

## Why

The self-test step for facts made the player type a `/run` line, because the Run button only runs allowed commands and `/run` is not allowed. A plan cannot carry `/run`, since imported data is never executed. The step is the only one in the self-test that needs typing.

## What Changes

- Add `/ct fact`. It takes no arguments and reports the fact `[CheckThat] selftest=1` through the same path as `CheckThat.Report`. It prints a line saying whether the fact was recorded.
- The self-test step `self.facts` runs `/ct fact` with the Run button, so the player only clicks.
- Manual checks 10 and 11 use the command. The README, the help text and the feature reference list it.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `fact-reporting`: a command reports a test fact so a plan can exercise the API with a click.

## Impact

- `CheckThat/Core/Slash.lua` (command and help line), `plans/selftest.yaml`, tests, README, `docs/features.md`, `docs/test-plan.md`.
- Addon code changes: 0.9.0 to 0.9.1 (new command on an existing capability).
