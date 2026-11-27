## ADDED Requirements

### Requirement: Flow replay covers async and inapplicable steps
`ct replay-flow` and `tests/replay_plan.lua` SHALL settle an async step at run start when its fixture lines exist before the first step, and SHALL report a step with an `unmet: inapplicable` requirement as inapplicable when the hooks file marks the requirement unmet.

#### Scenario: Async version step
- **WHEN** the fixture holds the version fact before the run starts
- **THEN** the replay records the step passed at start and never shows it
