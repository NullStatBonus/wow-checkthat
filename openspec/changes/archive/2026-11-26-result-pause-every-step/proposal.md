## Why

The pause and fade after an automatic result reads well in game, but a result the player records still jumps straight to the next step. The held view also repeats the whole step, so the result is hard to see. Sound for results (#229) needs one place to start.

## What Changes

- The card pauses on every result that moves the run on, the player's as well as CheckThat's.
- While it holds, the card shows only the title, one large result word in its color, who recorded it and the note.
- A result press during the pause is ignored with a chat line for both kinds of result. The chat and log text no longer say "automatic".
- `Card.ResultCue(verdict, by)` runs once when a pause starts. It does nothing yet; #229 adds the sound there.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-runner-ux`: every result pauses the card, with a simpler held view and a result cue.

## Impact

`CheckThat/UI/Card.lua`, `tests/test_card.lua`, `plans/checkthat-0.21.yaml`, `DESIGN.md`, `docs/features.md`, `docs/listing.md`, `docs/test-plan.md`, `docs/authoring-plans.md`, `CHANGELOG.md` (0.21.0, unreleased). No saved-variable or format change. Debug log line `result <verdict> ignored: the card was showing an automatic result` becomes `... showing a result`; it was never released.
