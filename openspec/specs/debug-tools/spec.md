# debug-tools Specification

## Purpose
The bounded debug log, the copyable report and the adapter rule for game calls.

## Requirements

### Requirement: Bounded debug log
While recording is on the addon SHALL keep the last 300 lines as `[area] message` entries with a time in saved variables, and SHALL record nothing when it is off. Failures that turn something off SHALL be recorded even when recording is off.

#### Scenario: Off
- **WHEN** recording is off
- **THEN** no lines are added

### Requirement: Copyable report
`/ct log` SHALL open a window with a selectable report: addon version, client, build, every saved setting, the current run status, failures, then the recorded lines.

#### Scenario: Copy
- **WHEN** the report opens
- **THEN** its text is selected-all ready for Ctrl+C

### Requirement: Game calls go through the adapter
Every game API read and action SHALL be in `Core/Adapter.lua`, guarded, returning nil when missing. Model code SHALL use no game globals. Frame construction, anchoring and styling in `UI/` and `Debug/` MAY call the game directly. Other modules SHALL NOT.

#### Scenario: Missing API
- **WHEN** a game function does not exist
- **THEN** the adapter returns nil and no Lua error is raised

#### Scenario: UI builds its own frames
- **WHEN** a file in `UI/` or `Debug/` calls `CreateFrame` or reads `UIParent`
- **THEN** the layering test passes

#### Scenario: Game global outside the allowed places
- **WHEN** a file in `Model/`, `Options/` or `Core/` other than the adapter uses a game global
- **THEN** the layering test fails and names the file
