## MODIFIED Requirements

### Requirement: Results survive reload
The runner SHALL keep the run in SavedVariables (`WoWTestThatDB.global.runs`), open an attempt before the player acts, keep that attempt (with its log snapshot) across `/reload`, resume the current step after login, and offer an immediate export string. Results SHALL be labelled "saved on reload" until the game flushes them. The runner's own log SHALL be readable as an evidence source at `WoWTestThatDB.global.log.entries`.

#### Scenario: Reload mid-step
- **WHEN** a step has `reload: after_action` and the player reloads
- **THEN** the same attempt is current after login and verifies against the log lines written during load
