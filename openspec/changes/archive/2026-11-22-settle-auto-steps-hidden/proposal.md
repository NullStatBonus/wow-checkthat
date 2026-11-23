## Why

An auto step is read on the card's half-second loop, which stops when the card is hidden. A player who hides the card during an auto step gets no result, and the timeout clock keeps running with nothing recorded. Issue #27.

## What Changes

- Run the auto-settle loop while a run has an open auto step, whether or not the card is shown.
- Keep the loop read-only. It sends no input and starts no game action.
- A hidden card that opens again shows the normal current step. The step recorded while hidden shows "recorded by CheckThat" through Undo or the "<" button, as today.
- Keep the stop when the game interface is hidden and when the Start screen of another plan shows.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `run-evidence`: the runner re-reads an open auto step without the card being shown.
- `test-runner-ux`: the "Card hidden" scenario now records the result.

## Impact

- `CheckThat/UI/Card.lua`: the `tick` loop and `Card.AutoSettle` split into a card refresh and a loop that does not depend on `card:IsShown()`.
- `CheckThat/Model/App.lua`: no logic change expected. The settle call is already model-side.
- `README.md`, `docs/listing.md`, `docs/test-plan.md` (check 7 and the "Good to know" line).
- Tests: `tests/test_app.lua`, and a card test in the UI harness if one exists.
- Addon code changes, so the version bumps at archive (patch: modifies existing behavior).
