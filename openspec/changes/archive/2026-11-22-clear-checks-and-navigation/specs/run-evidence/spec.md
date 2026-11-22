## ADDED Requirements

### Requirement: Fail moves on
A fail result SHALL move the run to the next pending step, like pass, partial and skip. Only an unverified result SHALL keep the step open. Undo SHALL reopen a failed step.

#### Scenario: Fail on the last step
- **WHEN** the tester records fail on the last pending step
- **THEN** the run is complete and shows the results

### Requirement: Missing evidence is explained in the log
When a result is recorded with a missing or contradicting required check, the log line SHALL end with the reason.

#### Scenario: Unverified
- **WHEN** a pass is recorded without the awaited line
- **THEN** the log reads "step <id> unverified evidence unverified: <reason>"
