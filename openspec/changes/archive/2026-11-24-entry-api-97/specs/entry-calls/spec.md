# Spec Delta

## Purpose
Let an addon expose named functions that an automatic plan step calls with literal arguments, so a plan can test addon code without a player action.

## ADDED Requirements

### Requirement: Addons register entries
CheckThat SHALL provide `CheckThat.Entry(addon, name, fn)`, and `CheckThat.API_VERSION` SHALL be 2. It SHALL return true when it stores the entry and false otherwise. It SHALL refuse an invalid name, a value that is not a function, and any registration while a run is open. It SHALL never raise an error to its caller.

#### Scenario: Registered at load
- **WHEN** an addon registers an entry before a run opens
- **THEN** the call returns true

#### Scenario: Registered during a run
- **WHEN** an addon registers an entry while a run is open
- **THEN** the call returns false and the entry is not stored

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
