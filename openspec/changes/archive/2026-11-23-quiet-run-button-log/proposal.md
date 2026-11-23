# Proposal

## Why

A saved run showed 268 of 300 debug lines were `run button hidden: nothing to run on this screen`. The game's state driver shows the Run button about five times a second, and CheckThat logged each time. The 300-line log rolled over in about a minute, so checks that a line is absent stayed unverified and older lines were lost.

## What Changes

- CheckThat logs the hidden Run button once for each screen, not once for each time the game shows the button.

## Capabilities

### New Capabilities

### Modified Capabilities
- `debug-tools`: the debug log does not repeat one line for one cause.

## Impact

- Code: `CheckThat/UI/Card.lua`. Tests: `tests/test_smoke.lua`. Docs: `docs/test-plan.md`, `docs/contracts.md`, `CHANGELOG.md` (0.8.0, not yet released).
