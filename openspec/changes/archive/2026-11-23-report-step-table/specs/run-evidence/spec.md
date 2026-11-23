## ADDED Requirements

### Requirement: The report lists every step
The central report (`ct.py report`) SHALL print, for each run, a table with one row per step in plan order: step id, verdict, evidence state, attempt count and note. Detail lines for attempts and evidence SHALL stay for steps that did not pass.

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
