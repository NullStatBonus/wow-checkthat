# run-evidence Specification

## Purpose
How runs, attempts, verdicts and evidence are recorded, kept across reload, and collected outside the game.

## Requirements

### Requirement: Runs are recorded with identity
Each run SHALL record run ID, revision, plan digest, client, client build, character, and per-step attempts with verdict (pass, fail, skip, unverified, plus pending and inapplicable steps), timestamps, assertion outcomes, claimed verdict, and notes. Every change SHALL bump the revision.

#### Scenario: Retry
- **WHEN** a step fails and is retried
- **THEN** a new attempt is recorded and the earlier attempt is kept

### Requirement: A pass needs its evidence
A claimed pass SHALL record as pass only if every required (non-diagnostic) assertion passes. Contradicting evidence SHALL record fail. Missing, unreadable, ambiguous, or rolled-over evidence SHALL record unverified and keep the step open. Diagnostic assertions SHALL be recorded without gating. Evidence SHALL be labelled matched only when at least one required assertion exists and all required assertions passed; a step whose assertions are all diagnostic SHALL be labelled diagnostic-only. A log assertion SHALL read only lines added after the attempt opened unless its scope is session. The attempt boundary SHALL be found by position in the log; if it cannot be located unambiguously the result is unverified. An absent assertion SHALL pass only when the window holds at least one new line.

#### Scenario: Missing log line
- **WHEN** the player claims pass and the required line is absent
- **THEN** the attempt records unverified with the claim retained

#### Scenario: Stale line
- **WHEN** the expected line exists only from before the attempt opened
- **THEN** the assertion is unverified

#### Scenario: Absence
- **WHEN** an assertion requires a line to be absent and it appears
- **THEN** the attempt records fail

#### Scenario: Absence with debug off
- **WHEN** no new log lines arrived during the attempt
- **THEN** an absent assertion is unverified, not pass

#### Scenario: Diagnostic only
- **WHEN** a step's assertions are all diagnostic and the player passes it
- **THEN** the attempt records pass with evidence diagnostic-only

#### Scenario: Repeated startup block
- **WHEN** the same startup lines appear in every session of the log and the player reloads mid-step
- **THEN** only lines after the snapshot position count as new

### Requirement: Results survive reload
The runner SHALL keep the run in SavedVariables (`TestThatDB.global.runs`), open an attempt before the player acts, keep that attempt (with its log snapshot) across `/reload`, resume the current step after login, and offer an immediate export string. Results SHALL be labelled "saved on reload" until the game flushes them. The runner's own log SHALL be readable as an evidence source at `TestThatDB.global.log.entries`.

#### Scenario: Reload mid-step
- **WHEN** a step has `reload: after_action` and the player reloads
- **THEN** the same attempt is current after login and verifies against the log lines written during load

### Requirement: Reviewer-only evidence is preserved
Where a plan names reviewer-only evidence, exports SHALL retain the exact reviewer instruction and the recorded outcome.

#### Scenario: Reviewer step
- **WHEN** a step has `reviewer` text
- **THEN** the report lists it with the step

### Requirement: External scripts collect evidence centrally
Provided scripts SHALL copy WTT and tested-addon SavedVariables from a WTF or saved-copy directory into one central directory, deduplicating by content hash and by run ID plus revision, convert SavedVariables and results strings to JSON, and write a readable report of every non-passing step. Scripts SHALL NOT modify game files.

#### Scenario: Duplicate collection
- **WHEN** the script runs twice with no new reload
- **THEN** the central directory has one copy per file and one file per run revision

### Requirement: Runs are bound to their plan and character
A run SHALL resolve its steps from the exact plan version (digest) it started with, even after a newer import. The active run SHALL be tracked per character and realm; another character SHALL not resume or read evidence for it.

#### Scenario: Reimport during a run
- **WHEN** a plan with changed step IDs is imported while a run is active
- **THEN** the active run keeps using the plan it started with

#### Scenario: Character switch
- **WHEN** another character logs in
- **THEN** it has no active run from the first character

### Requirement: Undo follows commit order
Undo SHALL revert the most recent verdict in the order verdicts were committed and drop any retry attempt opened after it.

#### Scenario: Undo after fail
- **WHEN** a step fails, a retry opens, and the player presses Undo
- **THEN** the failed verdict and the open retry are removed and earlier steps are untouched

### Requirement: Screenshots are collected by time window
A step MAY ask for a screenshot taken by the player with the game's own key. The collector SHALL copy screenshot files whose modification time falls inside an attempt's window into that run's folder, and the report SHALL list them under the step. The runner SHALL NOT capture screenshots itself.

#### Scenario: Screenshot in window
- **WHEN** a screenshot file was written during a step's attempt
- **THEN** collect copies it under the run and the report names it for that step

### Requirement: Partial verdict
A step MAY be recorded as partial, meaning it mostly works. A partial claim SHALL be gated by required evidence exactly like a pass: matched evidence records partial, contradicting evidence records fail, missing evidence records unverified. A partial step SHALL advance the run like a pass, SHALL be counted separately, and SHALL be listed in the report with its note.

#### Scenario: Partial with evidence
- **WHEN** the player records partial with a note and the required evidence matched
- **THEN** the attempt records partial with the note and the run moves to the next step

#### Scenario: Partial without evidence
- **WHEN** the player records partial and required evidence is missing
- **THEN** the attempt records unverified and the step stays open

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
