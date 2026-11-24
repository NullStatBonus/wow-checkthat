## ADDED Requirements

### Requirement: The card warns when errors cannot be seen
A step that reads the Lua error list SHALL show an amber line on the card while a run is open and nothing records errors (no handler of ours and no BugGrabber list). The line SHALL go when errors can be seen again.

#### Scenario: Blind
- **WHEN** a step with a no-error check is shown and nothing can see errors
- **THEN** the card shows an amber line saying CheckThat cannot see Lua errors
