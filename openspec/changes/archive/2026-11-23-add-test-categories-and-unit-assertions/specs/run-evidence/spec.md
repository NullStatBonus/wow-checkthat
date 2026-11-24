# Spec Delta

## ADDED Requirements

### Requirement: Fact assertions are judged on parsed values
A fact assertion SHALL read the facts of the named addon and key that arrived since the attempt opened. A value SHALL be a boolean for `true` and `false`, a number when it reads as one, else text. With no matching fact the result SHALL be unverified. With facts that break the operator the result SHALL be fail. `which: last` judges the newest fact, `any` passes when one matches, and `all` passes when every one matches.

#### Scenario: Value out of range
- **WHEN** a step needs `between [1, 5]` and the fact `level=9` arrives
- **THEN** the assertion fails and the step cannot pass

#### Scenario: Fact never arrives
- **WHEN** no fact with the key arrives
- **THEN** the assertion is unverified, not failed

#### Scenario: Number as text
- **WHEN** the fact reads `name=abc` and the assertion is `type number`
- **THEN** the assertion fails

#### Scenario: Approximate value
- **WHEN** a step needs `approx 0.5` with tolerance 0.01 and the fact reads 0.504
- **THEN** the assertion passes

### Requirement: Counts judge how many lines matched
With `count`, the result SHALL pass when the number of matching new lines fits. More than the maximum SHALL fail. Fewer than the minimum SHALL be unverified, as the line can still arrive. A count that allows zero SHALL need a readable log whose boundary is known, like an absence check.

#### Scenario: Too many, shown at once
- **WHEN** a step needs exactly two reports and a third arrives
- **THEN** the card shows the check as failed at once, not only when the result is recorded

#### Scenario: Called twice
- **WHEN** a step needs `exactly 2` and two matching lines arrive
- **THEN** the assertion passes

#### Scenario: Called three times
- **WHEN** a step needs `exactly 2` and three matching lines arrive
- **THEN** the assertion fails

#### Scenario: Called once
- **WHEN** a step needs `min 2` and one line has arrived
- **THEN** the assertion is unverified

### Requirement: Silence on a quiet source is a result
On a quiet source, an absence check or a count that allows zero SHALL pass when the log is readable, its boundary is known and no matching line arrived. An unreadable source SHALL stay unverified with the reason shown.

#### Scenario: No Lua errors
- **WHEN** a step needs no line on the quiet error source and none arrived
- **THEN** the assertion passes

#### Scenario: Source unreadable
- **WHEN** the plan's quiet source cannot be read
- **THEN** the assertion is unverified and says the source cannot be read

#### Scenario: Error expected
- **WHEN** a step needs one line matching a pattern on the error source and it arrived
- **THEN** the assertion passes

### Requirement: Lua errors are recorded while a run is open
While a run is open, CheckThat SHALL record each Lua error as one line in a bounded list in its saved variables, with the message cut to 200 characters, a rate limit like facts, and a debug log line. It SHALL pass every error on to the handler that was set before it and SHALL NOT raise errors itself. Plans read the list as a quiet log source. No error SHALL be recorded when no run is open.

#### Scenario: Error during a step
- **WHEN** an addon raises a Lua error while a run is open
- **THEN** a line with its message is added, the earlier handler still receives the error, and a step that needs no error line fails

#### Scenario: No run
- **WHEN** an error occurs with no run open
- **THEN** nothing is recorded

#### Scenario: Flood
- **WHEN** an addon raises hundreds of errors in one second
- **THEN** only the rate limit's worth are kept and one debug line says the rest were dropped

#### Scenario: Handler replaced
- **WHEN** another addon replaced the error handler after CheckThat set its own
- **THEN** CheckThat sets its handler again when a run starts or a category is triggered

#### Scenario: Handler slot held by BugGrabber
- **WHEN** BugGrabber holds the handler slot and makes setting a handler do nothing
- **THEN** the debug report shows the handler as blocked, and CheckThat records a line for each rise of a BugGrabber error counter, also for an error that was already in its list

#### Scenario: Error before the step
- **WHEN** an error counted by BugGrabber happened before a step opened
- **THEN** it does not count against that step

#### Scenario: Nothing is recording
- **WHEN** no handler is set, BugGrabber is not loaded, and the tester records a result on a step that needs no Lua error
- **THEN** CheckThat records a line that says it cannot see errors, and the step does not pass on silence

#### Scenario: Earlier handler raises
- **WHEN** the handler set before CheckThat's raises an error
- **THEN** CheckThat records the error, says so in the debug log, and raises nothing in the game's handler
