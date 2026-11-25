## ADDED Requirements

### Requirement: A run records the version of the addon under test
When a run starts, it SHALL carry `targetVersion`, the TOC `Version` of the plan's addon, read through a guarded adapter call. The key SHALL be omitted when the addon has no version or the client cannot say, and SHALL NOT be the text "unknown". `Run.FORMAT_REV` SHALL be 3 or higher, the schema and `docs/results-format.md` SHALL list the key, and a reader SHALL treat its absence as unknown.

#### Scenario: A version the game knows
- **WHEN** a run starts for a plan whose addon has a TOC version
- **THEN** the run holds that version as `targetVersion`

#### Scenario: A version the game cannot give
- **WHEN** the client has no metadata call, the call fails, or the version is empty
- **THEN** the run has no `targetVersion` key
