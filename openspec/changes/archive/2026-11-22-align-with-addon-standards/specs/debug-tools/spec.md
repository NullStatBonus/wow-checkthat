## ADDED Requirements

### Requirement: Bounded debug log
While recording is on the addon SHALL keep the last 300 lines as `[area] message` entries with a time in saved variables, and SHALL record nothing when it is off. Failures that turn something off SHALL be recorded even when recording is off.

#### Scenario: Off
- **WHEN** recording is off
- **THEN** no lines are added

### Requirement: Copyable report
`/wtt log` SHALL open a window with a selectable report: addon version, client, build, every saved setting, the current run status, failures, then the recorded lines.

#### Scenario: Copy
- **WHEN** the report opens
- **THEN** its text is selected-all ready for Ctrl+C

### Requirement: Game calls go through the adapter
Every game API read SHALL be in `Core/Adapter.lua`, guarded, returning nil when missing. Model code SHALL use no game globals.

#### Scenario: Missing API
- **WHEN** a game function does not exist
- **THEN** the adapter returns nil and no Lua error is raised
