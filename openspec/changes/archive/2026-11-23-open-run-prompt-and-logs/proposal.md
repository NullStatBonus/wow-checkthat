# Proposal

## Why

A test of the 0.8 plan showed three gaps. Open run asked nothing when it opened an ended run, so a player could not tell a prompt that failed to show from a prompt that was never due. Five plan steps could only be judged by eye because CheckThat wrote no log line for the export, the report and the questions. The Run button hide guard also wrote one log line about five times a second.

## What Changes

- Open run asks first whenever another run of this character is active, also for an ended run. The question says which of the two cases it is.
- The debug log gains `run open asked <id>`, `run delete asked <id>`, `run exported <id>` and `report requested: <Stored line>`.
- The Run button leaves the game's combat state driver while a step has nothing to run, so the game stops showing it again every 0.2 seconds. The hide guard stays as a fallback and logs once for each screen.

## Capabilities

### New Capabilities

### Modified Capabilities
- `addon-settings`: Open run asks first when a run is active.
- `debug-tools`: the log names exports, reports and questions; the hidden button writes one line for each screen.

## Impact

- Code: `CheckThat/Model/App.lua`, `CheckThat/Options/Options.lua`, `CheckThat/Debug/Log.lua`, `CheckThat/Core/Adapter.lua`, `CheckThat/UI/Card.lua`. Tests, README, `docs/test-plan.md`, `docs/contracts.md`, `plans/checkthat-0.8.yaml`, `CHANGELOG.md` (0.8.0, not yet released).
- Closes issues #46 and #47.
