# Spec Delta

## ADDED Requirements

### Requirement: An auto step records its own pass
While an auto step has an open attempt and the card is shown, the runner SHALL re-read the required assertions at least twice a second. When every required assertion is met, the runner SHALL record the pass by the same evidence gate as a player's pass, with the claim labelled `auto`, and SHALL move to the next pending step. Reading and recording SHALL send no input and SHALL start no game action.

#### Scenario: Line appears
- **WHEN** the awaited log line appears while an auto step is open
- **THEN** the step records pass with evidence matched and claim auto, without a button press

#### Scenario: Not all met
- **WHEN** one of two required assertions is met and the other is waiting
- **THEN** the step stays open and records nothing

#### Scenario: Player clicks first
- **WHEN** the player records fail on an auto step before its checks are met
- **THEN** the step records the player's result and the runner does not record another

#### Scenario: Undo
- **WHEN** the player undoes an automatic pass or any later result of the step
- **THEN** the step reopens and the runner can settle it again

#### Scenario: Reload requested
- **WHEN** an auto step asks for a reload after the action and its checks are met before the reload happened
- **THEN** the runner waits for the reload, and the timeout still settles the step

#### Scenario: Check changes between reads
- **WHEN** a check reads met on the card refresh but not when the runner records the result
- **THEN** the runner records nothing and tries again on the next refresh

### Requirement: An auto step settles at its timeout
When an auto step has a timeout and that many seconds have passed since its attempt opened with the checks not all met, the runner SHALL settle the step once, as an automatic pass claim through the evidence gate. A contradicted required assertion SHALL record fail. Missing, unreadable or rolled-over evidence SHALL record unverified and keep the step open. The step SHALL NOT fail only because a check read bad earlier and recovered before the timeout.

#### Scenario: Contradicting evidence at timeout
- **WHEN** the timeout passes and a required state check still reads wrong
- **THEN** the step records fail with evidence contradicts and claim auto

#### Scenario: Missing evidence at timeout
- **WHEN** the timeout passes and the awaited line never appeared
- **THEN** the step records unverified and stays open

#### Scenario: Recovery before timeout
- **WHEN** a required check reads bad and then reads met before the timeout
- **THEN** the step records pass

#### Scenario: Reload keeps the clock
- **WHEN** the player reloads the interface while an auto step is open
- **THEN** the timeout still counts from the time the attempt opened

### Requirement: An automatic result is settled once and labelled
The runner SHALL settle an auto attempt at most once. After an automatic unverified result the card opens the retry attempt as it does for any unverified step, but the runner SHALL NOT settle that attempt or any later one until the player acts. The attempt, the debug log line, the results string and the report SHALL show that the runner settled it, also while a retry is open.

#### Scenario: No loop of automatic results
- **WHEN** an auto step records unverified at its timeout and the retry attempt is open
- **THEN** the runner records no further automatic result until the player acts

#### Scenario: Reviewer can tell
- **WHEN** a reviewer reads the report for an automatic result, including while a retry attempt is open
- **THEN** the report labels the result as recorded by TestThat, not by the player
