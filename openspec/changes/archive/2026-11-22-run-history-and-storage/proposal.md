# Proposal

## Why

Every attempt saves a full copy of every log the plan declares, and imported plan revisions stay in saved variables forever. Saved data grows with each run. Older runs also have no screen: only the current run per character can be opened or exported in game. Fix the growth first so keeping old runs is cheap, then expose them. Covers issues #2 and #5.

## What Changes

- An attempt snapshots only the log sources that the step's attempt-scoped log assertions name.
- A snapshot stores the log length and the last 12 lines, not the whole log.
- A log check never treats an unsnapshotted source as "all lines are new". It gives "unverified".
- A plan copy that no run, loaded plan or recent-list entry uses is deleted.
- Home gets a Runs list: date, plan, counts, and Open, Export and Delete per run.
- Runs beyond a limit (newest kept) are pruned. Pruning never removes the current run.
- The debug report shows the run limit and how many runs and plans are stored.

## Capabilities

### New Capabilities

### Modified Capabilities
- `run-evidence`: attempt snapshots shrink and are limited to checked sources; stored plans and old runs are pruned.
- `addon-settings`: Home page gains a Runs list with a run limit setting.

## Impact

- Code: `CheckThat/Model/Evidence.lua`, `Model/Run.lua`, `Model/App.lua`, `Options/Options.lua`, `Core/` settings defaults, `Debug/` report.
- Saved variables: snapshots written by older versions still hold full arrays. They must keep working.
- Docs: README (Home page, new setting, Good to know), `docs/listing.md`, `docs/test-plan.md`.
- Addon code changes, so the version bumps at archive (minor: new Runs list).
