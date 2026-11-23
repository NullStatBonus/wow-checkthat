## Why

A long plan or step title runs past the right edge of the minimized card (#41). The card title menu holds only "End run...", so a player who wants another plan must find the Import button or a slash command (#40). The header label also reads as a heading, not as a menu.

## What Changes

- Keep every card title inside the card width. In the collapsed card a title is one line with an ellipsis and shows in full on hover. The expanded card allows two lines.
- Show the header as a visible "Run" menu control with a dropdown arrow and hover highlight. The whole control opens the menu.
- Menu items: "Import...", "End run...", "Clear plan...". Import opens the import box. Clear plan asks first, ends the run, keeps its results for export, and forgets the loaded plan.
- Fix the collapsed card header: the step counter sits left of the collapse and close buttons and no longer overlaps the menu.
- Keep the start screen at full width, size its text to the card, and put the first visible button at the left edge.
- After the last plan is forgotten, the ended screen offers "Import a plan" in place of "Main window".
- Remove the dedicated Reload button from the verdict row and the results screen. A reload step has the Run button beside its `/reload` command. Other reload requests tell the player to type `/reload`.
- Update README, `docs/listing.md` and `docs/test-plan.md`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `test-runner-ux`: new requirements for card text fitting, the Run menu control, Import, Clear plan and the ended screen after Clear plan. The "End run from the card" requirement stays as it is.

## Impact

- `CheckThat/UI/Card.lua`: header control, title font strings and tooltip, mini layout, start and ended screens, `Card.RunMenu`, a new confirm for Clear plan.
- `CheckThat/Model/App.lua`: new `App.ClearPlan`.
- New locale strings; tests in `tests/test_app.lua` and a card UI test; docs.
- Addon code changes, so archive bumps the version (new player-visible feature: minor).
