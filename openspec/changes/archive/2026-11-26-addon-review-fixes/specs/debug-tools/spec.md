## ADDED Requirements

### Requirement: The report lists what the plan reads
While a run is on the card, the debug report SHALL hold a line `Plan reads: <names>` with every global the plan's log sources and `global-value` checks read, or `Plan reads: none`. With no run the line is absent.

#### Scenario: Plan with a log source
- **WHEN** the plan of the run on the card has a log source on `KeepThatDB`
- **THEN** the report holds `Plan reads: KeepThatDB`
