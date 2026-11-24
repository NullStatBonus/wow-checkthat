# fact-reporting Specification

## Purpose
A sibling addon publishes named facts while a run is open, so a plan can check them as log evidence and an auto step can pass from them.

## Requirements

### Requirement: A public function records one fact
CheckThat SHALL provide `CheckThat.Report(addon, key, value)` and `CheckThat.API_VERSION`. While a run is open, an accepted call SHALL add the line `[addon] key=value` to the facts list in CheckThat's saved variables and SHALL return true. The function SHALL never raise an error to its caller and SHALL return false when it records nothing.

#### Scenario: Fact recorded
- **WHEN** an addon calls `CheckThat.Report("KeepThat", "bagFull", true)` during an open run
- **THEN** the list gains the line `[KeepThat] bagFull=true` and the call returns true

#### Scenario: No run is open
- **WHEN** an addon calls `Report` with no run open or after the run ended
- **THEN** nothing is recorded, nothing is raised and the call returns false

#### Scenario: Bad arguments
- **WHEN** an addon passes a table, a function, an empty name, a key with spaces or a value with a line break
- **THEN** nothing is recorded, nothing is raised and the call returns false

### Requirement: Facts are data only and bounded
A value SHALL be a string, a finite number or a boolean. The addon name, the key and a string value SHALL each have a length limit. The list SHALL keep a fixed number of recent lines. One addon SHALL be able to record only a fixed number of facts per second. A fact over a limit SHALL be dropped, and the debug log SHALL name the addon and the reason.

#### Scenario: Flood
- **WHEN** an addon reports far more facts in one second than the limit
- **THEN** the facts over the limit are dropped, the list keeps the earlier ones and other addons are unaffected

#### Scenario: Long list
- **WHEN** the list is full and a new fact arrives
- **THEN** the oldest line is removed

### Requirement: Plans read facts as a log
A plan SHALL read facts through a log source for the `CheckThatDB` global at `global.facts` with format `strings`. Assertions on it SHALL follow the same rules as any log: positions, absence after a roll, and auto steps. The plan format SHALL need no change.

#### Scenario: Auto step passes from a fact
- **WHEN** an auto step requires the line `[KeepThat] bagFull=true` and the addon reports it during the step
- **THEN** the step records pass with claim auto, without a player click

#### Scenario: Fact from before the step
- **WHEN** the line was reported before the step opened
- **THEN** the step does not count it

### Requirement: The API only grows
`API_VERSION` SHALL be 1 for this release. A later release SHALL keep every released argument, return value and line format working and SHALL raise `API_VERSION` only when it adds something.

#### Scenario: Addon built for version 1
- **WHEN** a later CheckThat release loads with an addon that calls `Report` as released
- **THEN** the call behaves the same

### Requirement: The debug report counts facts
The debug report SHALL show how many facts are recorded and the last one. The debug log SHALL record each accepted fact and each dropped fact with its reason when recording is on. `Report` SHALL add no setting.

#### Scenario: Report after facts
- **WHEN** facts were recorded and the player opens the report
- **THEN** the report shows the count and the last line
