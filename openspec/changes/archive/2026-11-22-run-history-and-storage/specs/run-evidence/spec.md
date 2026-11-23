## ADDED Requirements

### Requirement: Attempts snapshot only the logs a step checks
When a step opens an attempt, CheckThat SHALL record a position in each log source that an attempt-scoped log or log-sequence assertion of that step names, and in no other log. A position SHALL hold the log length and its last 12 lines. A log source that a step does not check MUST NOT be recorded for that step.

#### Scenario: Unchecked log is not recorded
- **WHEN** a plan declares logs "debug" and "other" and a step checks only "debug"
- **THEN** the attempt of that step holds a position for "debug" and none for "other"

#### Scenario: Session-scope assertion needs no position
- **WHEN** a step's only log assertion has session scope
- **THEN** the attempt records no log position

### Requirement: A log without a position is never all new
When an attempt-scoped assertion names a log source that has no position in the attempt, the check SHALL give "unverified" and MUST NOT count the whole log as new lines.

#### Scenario: Missing position
- **WHEN** an attempt lacks a position for the asserted source and the log holds a matching line
- **THEN** the check does not pass and the note says the log position is missing

### Requirement: Older full snapshots stay usable
A run saved with full-array snapshots SHALL keep checking correctly after an update.

#### Scenario: Old run after update
- **WHEN** an open attempt holds a full-array snapshot
- **THEN** its new lines are found as before

### Requirement: Unused plan copies are pruned
CheckThat SHALL delete a stored plan copy that no stored run, no loaded plan and no recent-list entry names. Pruning SHALL run when a plan is imported, a plan is cleared or a run is deleted.

#### Scenario: Orphan after Clear plan
- **WHEN** a plan was imported twice with different content and only one revision has a run
- **THEN** the other revision is deleted at the next import or clear

#### Scenario: Run keeps its plan
- **WHEN** a stored run names a plan copy
- **THEN** that copy stays, even when it is not loaded

### Requirement: Old runs are pruned to a limit
CheckThat SHALL keep at most the configured number of runs, newest first, and MUST NOT delete the current run of any character.

#### Scenario: Limit reached
- **WHEN** a new run starts and the limit is exceeded
- **THEN** the oldest non-current run is deleted and its plan copy follows the pruning rule
