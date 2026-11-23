# Proposal

## Why

The start screen buries the plan title in a sentence ("Plan ready: <title> (N steps). Select Start run.") under a generic "Ready to test" heading. A player with several plans cannot see at a glance which one Start run begins. See GitHub issue #42.

## What Changes

- With a plan pending, the heading is the plan title. The line under it reads "N steps. Ready to test. Select Start run." with a singular form for one step.
- With no plan, the heading is "No plan yet" and the line under it reads "Select Import a plan and paste a plan string."
- The "Select Start run" wording stays. The earlier retitle ("Ready to test", commit 9833fc8) is kept as status text, not dropped.
- The "CheckThat" card header and the footer buttons stay as they are. Start run stays first.
- A title longer than two lines shows in full in the existing title tooltip.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-runner-ux`: "Import opens the window" and "Start screen layout" describe the new heading and the line under it.

## Impact

- `CheckThat/UI/Card.lua` (`Card.Refresh`, start-screen branch) and its locale keys.
- `tests/test_card.lua`, `tests/test_locale.lua` coverage of the new keys.
- `README.md`, `docs/listing.md`, `docs/test-plan.md` wording for the start screen.
- Addon code changes, so the version bumps at archive.
