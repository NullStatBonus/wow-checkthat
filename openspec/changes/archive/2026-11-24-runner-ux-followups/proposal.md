# Proposal

## Why

Four small gaps remain in the runner and the report. A category picked by mistake cannot leave a run. A plan with more than 8 categories cannot be picked on the card, and one with more than 24 cannot be picked fully at all. Verdicts need a click or a slash command. The report shows stale evidence for reopened steps, loses stacks of recovered failures, and a slash verdict keeps no error stack.

## What Changes

- Remove from run: a category with no recorded result leaves the run. Menu item in the Categories window.
- A Choose categories window (paged checkbox list) for plans with more than 8 categories. The Home page lists any number of categories in pages of 24.
- Optional key bindings for Pass, Fail and Skip, unbound by default (#7 names Pass, Fail and Skip; Partial is included for parity with the card).
- Report: stacks match each attempt; a reopened step shows "awaiting retry" with evidence `none`; a verdict opened from a slash command arms the error stack like the card does.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `test-categories`: a category with no results can be removed from a run.
- `test-runner-ux`: the start flow lists any number of categories; key bindings for verdicts.
- `run-evidence`: stacks per attempt, reopened-step evidence, stack for a slash-opened attempt.

## Impact

- Code: `CheckThat/Model/Run.lua`, `Model/App.lua`, `UI/Card.lua`, `UI/Tracker.lua` (shared paging), a new `UI/Picker.lua`, `Options/Options.lua`, new `Bindings.xml`, `Locales/enUS.lua`, `tools/ct.py`.
- Docs: README, `docs/features.md`, `docs/listing.md`, `docs/test-plan.md`, `docs/harvesting.md`.
- Addon code changes: version bump (minor, new player-visible capability) and changelog at archive.
- Closes #81, #60, #77, #7.
