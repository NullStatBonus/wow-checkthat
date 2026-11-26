## MODIFIED Requirements

### Requirement: The API only grows
`API_VERSION` SHALL be 3 for this release (2 from 0.18.0, 1 before). A later release SHALL keep every released argument, return value and line format working and SHALL raise `API_VERSION` only when it adds something.

#### Scenario: Addon built for version 1
- **WHEN** a later CheckThat release loads with an addon that calls `Report` as released
- **THEN** the call behaves the same
