## ADDED Requirements

### Requirement: A timed log finds where the step opened
For a log of `{ t, msg }` entries in which every entry has a number `t`, a saved log position SHALL keep the times of its tail lines. A tail line SHALL match only a line with the same text and time. When the saved tail spans more than one time and it is found at one place, that place SHALL be exact, also when the log is full and its lines repeat. When it is found at more than one place, the place SHALL NOT be exact. A position without times, a tail at a single time, and a log without times SHALL use the rules without times.

#### Scenario: Repeated block in a full log
- **WHEN** a full 300-line log of timed entries repeats the same block, the step opened after one copy, and nothing it must not log arrived
- **THEN** the absence check passes

#### Scenario: Position saved by an older CheckThat
- **WHEN** a position has no times and its tail appears more than once
- **THEN** the absence check stays unverified

#### Scenario: Clock ran back
- **WHEN** the saved lines appear twice with the same times
- **THEN** the place is not exact
