# Proposal

## Why

The ClosestVendor sample plan asks the player to confirm nearly every step, so CheckThat verifies almost nothing by itself. Covers issue #13. (The report table, issue #10, moved to change `report-step-table`.)

## What Changes

- ClosestVendor sample steps gain labelled required log assertions, but only for log lines measured in a collected run. Each measured line goes into `docs/contracts.md`.
- Finding: the saved ClosestVendor logs now in `../shared-addon-resources/saved` hold only startup and event lines. They hold no "test command" or "question shown" lines. A new in-game run with `/cvn debug on` must produce the lines first.

## Capabilities

### New Capabilities

### Modified Capabilities

## Impact

- Plans and docs: `plans/closestvendor.yaml`, `docs/contracts.md`, `docs/test-plan.md` if the sample's checks change.
- No file under `CheckThat/` changes. No version bump, no changelog entry, no tag.
