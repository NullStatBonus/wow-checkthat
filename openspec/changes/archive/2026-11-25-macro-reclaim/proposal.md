# Proposal

## Why

When the tester edits the CT macro, CheckThat treats it as the player's macro for good. In the next run the macro never follows again, and the key on the bar keeps running a stale macro. A saved run showed this: the plan's own edit step left the macro stuck. See change `macro-follow`, issue #103.

## What Changes

- A macro the player changed stays as it is for the rest of that run (unchanged).
- A new run, or turning the setting on, takes the macro back when its first line is still the marker `/ct macrorun`. The player's edit lasts one run.
- A macro without the marker line stays the player's for good.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `test-runner-ux`: the follow requirement says when a changed macro is taken back.

## Impact

- `CheckThat/UI/Card.lua` (`writeMacro`, `FollowMacro`), `docs/features.md`, README. Tests in `tests/test_combat.lua`.
- Version stays 0.20.0 (unreleased); the changelog line is unchanged in meaning.
