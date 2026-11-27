## ADDED Requirements

### Requirement: Plan command checks are explained in the log
At run start CheckThat SHALL log, for each plan command it checks with the game, which `SLASH_` global it found and who owns it, or why it found no owner.

#### Scenario: A command the addon registered
- **WHEN** CTProbe registered `/ctp` and a run of its plan starts
- **THEN** the log has `plan command /ctp: SLASH_CTPROBE1 by CTProbe`
