## MODIFIED Requirements

### Requirement: A failed attempt keeps the log lines that arrived
When an attempt records fail or unverified, it SHALL keep, for each log its step checks (not `session` scope), the first 20 new lines, each cut to 200 characters, as `excerpt`. A pass SHALL keep none. A log that cannot be read, or whose start is lost, SHALL add none. A run SHALL keep at most about 60 000 bytes of excerpt lines and check hit text together: when it holds more, the attempts that finished earliest lose their excerpt and hit text first. The results string SHALL stay version 1. The report SHALL print the lines under the attempt.

#### Scenario: A failure
- **WHEN** a step fails after 30 new log lines
- **THEN** its attempt holds the first 20, each at most 200 characters, and the report prints them

#### Scenario: A pass
- **WHEN** a step passes
- **THEN** its attempt holds no excerpt

#### Scenario: Over the budget
- **WHEN** the excerpts and hits of a run exceed the budget
- **THEN** the oldest attempts lose theirs and the newest keep them

## ADDED Requirements

### Requirement: A check that did not pass records what it looked at
Each check outcome that is not a pass SHALL record, from the same lines the check judged, its `kind`, `scope`, `source`, `label`, a `rule` in words, `window` (lines looked at), `matched`, and up to 3 `hits` of `{n, line}` where `n` is the 1-based position inside the window and `line` is cut to 200 characters. This SHALL hold also for a failing diagnostic in a passing attempt. A passing outcome SHALL record none of these. Every key SHALL be optional and the results string SHALL stay version 1.

#### Scenario: A forbidden line
- **WHEN** an absent check fails because two new lines match
- **THEN** its outcome says `a forbidden line appeared`, has `matched` 2 and a hit for each line with its position

#### Scenario: A count over its bound
- **WHEN** a count allows one match and three lines match
- **THEN** the first hit is the second matching line

#### Scenario: A sequence that stopped
- **WHEN** a sequence of three lines finds two
- **THEN** the outcome has `matched` 2, `stoppedAt` 3 and a hit for item 2

#### Scenario: No match
- **WHEN** a check finds no matching line
- **THEN** it records `matched` 0 and no hits

### Requirement: Sequence, fact and state checks add their own detail
A sequence SHALL record `item` on its hit and `stoppedAt`. A fact hit SHALL record its `value`. A state check SHALL record `observed`.

#### Scenario: A fact
- **WHEN** a fact check fails on its last fact
- **THEN** the hit is that fact's line, with its position and value

### Requirement: Hit text that is dropped for size is marked
When a run is over its byte budget, an attempt that loses its hit text or observed value SHALL keep each check's `rule`, `shape`, `matched`, `window` and reason and SHALL mark the check `trimmed`. The budget SHALL hold for every attempt that kept such text, a passing one too.

#### Scenario: Trimmed
- **WHEN** the budget forces the oldest attempt to drop its hits
- **THEN** its failed checks keep their rule and counts, have no hits and are marked trimmed

### Requirement: Tools can read the check detail
`schema/run-results.schema.json` SHALL describe the run record with these keys. `ct.py` SHALL treat a revision with malformed hits or counts as unreadable. The Markdown report SHALL print each check that did not pass with its rule, counts and hit lines, and mark the hit lines in the excerpt.

#### Scenario: A run the addon wrote
- **WHEN** a run saved by the addon with a failed check is validated
- **THEN** it passes the schema and the report names the rule and the lines

### Requirement: Machine reports keep log text opt-in
JSON and JUnit reports SHALL include the rule's `shape` (the rule with the plan's literals left out), counts and hit positions, and SHALL include line text, values and the full rule only when asked. JUnit SHALL take a failure's checks from the attempt its result comes from.

#### Scenario: Line text is opt-in
- **WHEN** a JSON report is made without `--lines`
- **THEN** it has hit positions and no line text
