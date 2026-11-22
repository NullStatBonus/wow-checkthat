## ADDED Requirements

### Requirement: Runs are recorded with identity
Each run SHALL record run ID, revision, plan digest, client, client build, character, and per-step attempts with verdict (pass, fail, skip, unverified, plus pending and inapplicable steps), timestamps, assertion outcomes, claimed verdict, and notes. Every change SHALL bump the revision.

#### Scenario: Retry
- **WHEN** a step fails and is retried
- **THEN** a new attempt is recorded and the earlier attempt is kept

### Requirement: A pass needs its evidence
A claimed pass SHALL record as pass only if every required (non-diagnostic) assertion passes. Contradicting evidence SHALL record fail. Missing, unreadable, or rolled-over evidence SHALL record unverified and keep the step open. Diagnostic assertions SHALL be recorded without gating. A log assertion SHALL read only lines added after the attempt opened unless its scope is session. The log tail snapshot SHALL be matched against the ring buffer; lost overlap is unverified.

#### Scenario: Missing log line
- **WHEN** the player claims pass and the required line is absent
- **THEN** the attempt records unverified with the claim retained

#### Scenario: Stale line
- **WHEN** the expected line exists only from before the attempt opened
- **THEN** the assertion is unverified

#### Scenario: Absence
- **WHEN** an assertion requires a line to be absent and it appears
- **THEN** the attempt records fail

### Requirement: Results survive reload
The runner SHALL keep the run in SavedVariables, open an attempt before the player acts, keep that attempt (with its log snapshot) across `/reload`, resume the current step after login, and offer an immediate export string. Results SHALL be labelled "saved on reload" until the game flushes them.

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
