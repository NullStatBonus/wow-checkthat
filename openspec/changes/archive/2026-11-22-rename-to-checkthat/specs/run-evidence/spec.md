# Spec Delta

## MODIFIED Requirements

### Requirement: Results survive reload
The runner SHALL keep the run in SavedVariables (`CheckThatDB.global.runs`), open an attempt before the player acts, keep that attempt (with its log snapshot) across `/reload`, resume the current step after login, and offer an immediate export string. Results SHALL be labelled "saved on reload" until the game flushes them. The runner's own log SHALL be readable as an evidence source at `CheckThatDB.global.log.entries`.

#### Scenario: Reload mid-step
- **WHEN** a step has `reload: after_action` and the player reloads
- **THEN** the same attempt is current after login and verifies against the log lines written during load

### Requirement: An automatic result is settled once and labelled
The runner SHALL settle an auto attempt at most once. After an automatic unverified result the card opens the retry attempt as it does for any unverified step, but the runner SHALL NOT settle that attempt or any later one until the player acts. The attempt, the debug log line, the results string and the report SHALL show that the runner settled it, also while a retry is open.

#### Scenario: No loop of automatic results
- **WHEN** an auto step records unverified at its timeout and the retry attempt is open
- **THEN** the runner records no further automatic result until the player acts

#### Scenario: Reviewer can tell
- **WHEN** a reviewer reads the report for an automatic result, including while a retry attempt is open
- **THEN** the report labels the result as recorded by CheckThat, not by the player
