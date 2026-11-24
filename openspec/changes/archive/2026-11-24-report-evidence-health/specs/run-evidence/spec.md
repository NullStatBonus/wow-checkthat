## MODIFIED Requirements

### Requirement: The report lists every step
The central report (`ct.py report`) SHALL print, for each run, a `result:` line (ok, UNVERIFIED or FAIL with counts) and a table with one row per step in plan order: step id, verdict, evidence state, attempt count and note. Detail lines for attempts and evidence SHALL stay for steps that did not pass. A step that passed after a failed or unverified attempt SHALL list those attempts too.

#### Scenario: Passing step with evidence
- **WHEN** a run holds a step that passed through a log assertion
- **THEN** the table has a row for it with verdict pass, evidence state met and its attempt count

#### Scenario: Passing step without evidence
- **WHEN** a step passed on the player's click alone
- **THEN** the row shows evidence state none and the step has no detail lines

#### Scenario: Failing step keeps its detail
- **WHEN** a step failed
- **THEN** the table has a row and the attempt and evidence detail lines follow as before

#### Scenario: Unverified evidence
- **WHEN** a step has an assertion outcome that is unverified or has no result
- **THEN** its row shows evidence state missing

#### Scenario: A pass after a rerun
- **WHEN** a step failed once and passed on its second attempt
- **THEN** the report lists the failed attempt under the step

### Requirement: A failed attempt keeps the log lines that arrived
When an attempt records fail or unverified, it SHALL keep, for each log its step checks (not `session` scope), the first 20 new lines, each cut to 200 characters, as `excerpt`. A pass SHALL keep none. A log that cannot be read, or whose start is lost, SHALL add none. A run SHALL keep at most about 60 000 bytes of excerpt lines: when it holds more, the attempts that finished earliest lose their excerpt first. The results string SHALL stay version 1. The report SHALL print the lines under the attempt.

#### Scenario: A failure
- **WHEN** a step fails after 30 new log lines
- **THEN** its attempt holds the first 20, each at most 200 characters, and the report prints them

#### Scenario: A pass
- **WHEN** a step passes
- **THEN** its attempt holds no excerpt

#### Scenario: Over the budget
- **WHEN** the excerpts of a run exceed the budget
- **THEN** the oldest attempts lose theirs and the newest keep them

## ADDED Requirements

### Requirement: One error stack for each attempt
CheckThat SHALL ask for an error stack only when a step opens a new attempt, not when the card refreshes an attempt that is already open.

#### Scenario: Card refresh
- **WHEN** the card refreshes a step whose attempt is open
- **THEN** no second stack is requested

### Requirement: The report shows error stacks
`collect` SHALL keep the saved error lines and call stacks. The report SHALL print, under a failed or unverified attempt, each error whose `<time>.<counter>` key falls in the attempt's open time, with its stack, and SHALL say when the time also fits another attempt. Json and junit reports SHALL leave stacks out unless asked.

#### Scenario: A stack in the window
- **WHEN** an error with a stack was raised while a failed attempt was open
- **THEN** the report prints the error and its stack under that attempt

#### Scenario: Stacks stay private by default
- **WHEN** a json or junit report is made without `--stacks`
- **THEN** it holds no stack text

### Requirement: The report has machine-readable formats
`ct.py report` SHALL support `--format json` and `--format junit`, and `--strict`. One rule SHALL classify each step for every format: a pass or partial claim with a failed required outcome is a fail, one with a required outcome without a result is unverified. Fail and unverified are failures in JUnit; pending, skip, deselected and inapplicable are skipped with a reason; partial passes. `--strict` SHALL exit 1 when any step failed or is unverified, or no run exists.

#### Scenario: CI gate
- **WHEN** `report --format junit --strict` runs over a run with a failed step
- **THEN** the XML holds a failure for that step and the exit code is 1

### Requirement: Status checks the evidence folder
`ct.py status` SHALL print one row for each run at its newest readable revision (steps done over steps that apply, fail, unverified and open counts, age, estimated export size), and SHALL name every unreadable revision, every conflict or decode failure `collect` logged, and any run over 80% of the 2 MB export limit. It SHALL exit 1 when it names a problem or finds no run, and SHALL NOT judge test results.

#### Scenario: A damaged revision
- **WHEN** the newest revision file of a run is not valid JSON
- **THEN** status names it, still shows the newest readable revision and exits 1

#### Scenario: A clean folder
- **WHEN** every revision is readable and nothing conflicts
- **THEN** status says there are no problems and exits 0

### Requirement: Open-attempt snapshots are not a conflict
`collect` and `import-results` SHALL compare two stored copies of one run revision as an export would hold them. Copies that differ only by open-attempt snapshots SHALL NOT conflict.

#### Scenario: Collected, then imported
- **WHEN** a revision is collected from saved variables and the same revision is imported from `/ct export`
- **THEN** the second store reports the same revision, not a conflict
