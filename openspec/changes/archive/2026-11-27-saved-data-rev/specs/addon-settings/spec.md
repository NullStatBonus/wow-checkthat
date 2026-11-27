## ADDED Requirements

### Requirement: Saved data carries its shape revision
The addon SHALL keep the shape revision of the saved global table in `dbRev`. A table without it SHALL count as revision 0, the shape of 0.21.0, and SHALL get revision 1 at load with no other change. Each migration SHALL take one revision to the next and SHALL run once. A revision above the one this version writes SHALL be left unchanged.

#### Scenario: Data from 0.21.0
- **WHEN** the addon loads saved data with no `dbRev`
- **THEN** `dbRev` is 1 and every other key is as it was

#### Scenario: Data from a newer version
- **WHEN** the addon loads saved data whose `dbRev` is above its own
- **THEN** `dbRev` keeps its value and the debug log says it was left as it is
