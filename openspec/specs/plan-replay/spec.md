# plan-replay Specification

## Purpose
Judge a plan's checks offline against a saved-variables fixture, so a plan edit or a log text change fails a build before a tester runs the plan.

## Requirements

### Requirement: Replay judges checks against a fixture
`ct.py replay <plan> --sv <dir>` SHALL judge each step's log and fact assertions against the decoded saved variables in the fixture, using the whole log as the window. It SHALL print JUnit and exit non-zero when a required check is contradicted.

#### Scenario: Typo in a log check
- **WHEN** a plan's `contains` text matches no line in the fixture
- **THEN** the step fails and the exit code is non-zero

#### Scenario: Corrected plan
- **WHEN** the typo is fixed
- **THEN** the step passes and the exit code is zero

#### Scenario: Forbidden line present
- **WHEN** a required `absent` check names a line the fixture holds
- **THEN** the step fails

### Requirement: Checks that need a window never pass offline
A check that needs a step window (`exactly`, `max`, `absent` on an attempt scope) or a state probe the fixture lacks SHALL report "not judged offline". It SHALL NOT count as a pass.

#### Scenario: State probe without data
- **WHEN** a step needs a state value the fixture does not hold
- **THEN** the report marks it not judged offline and the build does not count it as passed

### Requirement: Report names the fixture's age
The report SHALL print the fixture's age and the plan digest it was recorded with, and SHALL warn when the digest differs from the plan being replayed.

#### Scenario: Stale fixture
- **WHEN** the fixture was recorded for another plan digest
- **THEN** the report prints a stale-fixture warning
