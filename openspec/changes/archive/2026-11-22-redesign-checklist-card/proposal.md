# Proposal

## Why

The first live run showed the checklist card is hard to use: commands sit below the text they belong to, every line looks the same, progress is a counter, and importing a plan does nothing visible. Codex reviewed the layout and proposed a clearer hierarchy.

## What Changes

- Importing a plan opens the window at once, showing the plan and a Start run button.
- Layout: step title large; Setup, Do and Expect in a labelled column; each command beside the Do step with the Run all button next to the first command; a pinned note field and verdict row; thin progress bar; one-line mini mode; results screen with counts, Export results and Reload.
- Missing evidence gets its own amber line with the reason and one next action.
- Cut: the live verdict tally and the repeated "then press Pass" line.

## Capabilities

### Modified Capabilities
- `test-runner-ux`: window opens on import; card layout and states

## Impact

`TestThat/UI/Card.lua`, `DESIGN.md`, `docs/test-plan.md`, `CHANGELOG.md`, smoke test.
