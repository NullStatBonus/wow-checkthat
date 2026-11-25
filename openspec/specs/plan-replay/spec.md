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

### Requirement: Flow replay works for any addon's plan
`ct.py replay-flow <plan>` SHALL play every step of the plan in the fake client and exit non-zero on a problem. For a log source that is not CheckThat's own, it SHALL write the lines the step's checks look for into that source, derived from literal lines, patterns and sequences. It SHALL print that the evidence is assumed, and SHALL report a check it cannot derive instead of guessing.

#### Scenario: Plan for another addon replays without hooks
- **WHEN** a plan for another addon asserts log patterns in that addon's saved variable
- **THEN** the replay settles each automatic step and prints "evidence assumed"

#### Scenario: Pattern with no sample
- **WHEN** a check's pattern has a back-reference
- **THEN** the replay warns "evidence not derived" and the step does not settle

### Requirement: Bundle runs replay and offline without a checkout
The installed skill SHALL run `validate`, `compile`, `replay-flow` and `offline` from a folder that has no CheckThat checkout beside it.

#### Scenario: Run from another folder
- **WHEN** the skill is installed and `replay-flow` and `offline` run with another folder as the working folder
- **THEN** both succeed and write nothing to that folder

### Requirement: Asserted lines are checked against the addon source
`ct.py lines <plan> --addon-src <folder>` SHALL list each asserted log line and fact key that no Lua file of the addon contains, and exit non-zero only with `--strict`.

#### Scenario: Line missing from the source
- **WHEN** a plan asserts a line the addon source lacks
- **THEN** the command names the step and the line
