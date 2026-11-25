# Proposal

## Why

A tester plays a manual step in three moves: run its commands, look at the result, press a result key. The result keys exist (0.16.0). The commands have no key: `/ct macro` fills the `CT` macro for the current step only when the tester types it again for each step, so the macro goes stale. A tester cannot bind one key to `CT` and play a whole plan from the keyboard. See issue #103.

## What Changes

- New setting **Keep the CT macro on the current step** (profile, off by default, `macroFollow`). When on, CheckThat rewrites the `CT` macro each time the current step changes (result, Back, Next, Undo, a jump from the Categories window, a new run or plan).
- The macro holds the step's commands only. It never holds `/ct pass` or any result command.
- A step with no usable commands gets the harmless body `/ct status`.
- A rewrite in combat waits for the end of combat. The macro never changes in combat.
- Only a macro CheckThat made and the player has not edited is rewritten. A macro the player made or changed is never overwritten.
- Each rewrite logs `macro set <step id>`. The setting is in the debug report.
- The card says so when the step has commands but no macro can hold them (too many lines, too long for a macro, or not on the allow list).
- `/ct macro` keeps working as before.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `test-runner-ux`: a macro that follows the current step.
- `addon-settings`: the new setting, its default and its place in the debug report.

## Impact

- `CheckThat/UI/Card.lua` (`MakeMacro`, step-change hook, combat queue), `CheckThat/Model/App.lua` (`MacroText` length check), `CheckThat/Core/Defaults.lua`, `CheckThat/Options/Options.lua`, the debug report.
- Addon code changes, so this needs a version bump (new player-visible feature, minor).
- Docs: README (setting, "Good to know"), `docs/features.md`, `docs/listing.md`, `docs/test-plan.md`.
- Tests: `tests/test_app.lua`, `tests/test_combat.lua`, `tests/test_options.lua`.
