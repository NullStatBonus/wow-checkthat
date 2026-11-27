# entry-calls Specification

## Purpose
Let an addon expose named functions that an automatic plan step calls with literal arguments, so a plan can test addon code without a player action.

## Requirements

### Requirement: Addons register entries
CheckThat SHALL provide `CheckThat.Entry(addon, name, fn)`, and `CheckThat.API_VERSION` SHALL be 3. It SHALL return true when it stores the entry and false otherwise. It SHALL refuse an invalid name and a value that is not a function. It SHALL accept a registration while a run is open, because a run survives a reload and CheckThat loads before the addons that register. It SHALL never raise an error to its caller.

#### Scenario: Registered at load
- **WHEN** an addon registers an entry before a run opens
- **THEN** the call returns true

#### Scenario: Registered during a run
- **WHEN** an addon registers an entry while a run is open
- **THEN** the call returns true and the entry is stored

### Requirement: An auto step calls an entry
An auto step with a `call` field SHALL call the named entry with the literal arguments when its attempt opens, in a protected call, never in combat. The outcome SHALL be recorded as the fact `[addon] entry.<name>=<result>`. The result SHALL be the returned values joined by commas, `(none)` for no values, `threw: <text>`, `not registered` or `refused: in combat`. An attempt that stays open across a reload SHALL NOT call the entry again.

#### Scenario: Returned value
- **WHEN** the entry returns 5 and the step asserts `[KeepThat] entry.add=5`
- **THEN** the step passes

#### Scenario: Wrong value
- **WHEN** the entry returns 5 and the step asserts 6
- **THEN** the step does not pass

#### Scenario: Unregistered name
- **WHEN** the named entry was never registered
- **THEN** the fact reads `not registered` and the entry does not run

#### Scenario: Combat
- **WHEN** the player is in combat at step open
- **THEN** the entry does not run and the fact reads `refused: in combat`

### Requirement: An addon may declare its slash commands
`CheckThat.Commands(addon, list)` SHALL store 1 to 8 slash command prefixes for the addon and return true, and SHALL return false without raising for any other input, for a denied command, or for another known addon's command. `CheckThat.API_VERSION` SHALL be 4.

#### Scenario: Declared commands
- **WHEN** MyAddon calls `CheckThat.Commands("MyAddon", { "/my" })`
- **THEN** it returns true, and a plan for MyAddon that uses `/my` imports and offers it

#### Scenario: Denied command
- **WHEN** an addon calls `CheckThat.Commands("MyAddon", { "/run" })`
- **THEN** it returns false and stores nothing
