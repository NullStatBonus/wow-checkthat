## MODIFIED Requirements

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

## ADDED Requirements

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
