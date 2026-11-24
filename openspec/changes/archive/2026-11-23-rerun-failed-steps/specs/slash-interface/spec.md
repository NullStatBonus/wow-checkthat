## ADDED Requirements

### Requirement: Rerun takes failed
`/ct rerun failed` SHALL ask, then reopen the failed and unverified steps of the run. Its usage line SHALL read `/ct rerun <category or failed>`.

#### Scenario: Usage
- **WHEN** the tester types `/ct rerun` with no name
- **THEN** the usage line names both a category and failed
