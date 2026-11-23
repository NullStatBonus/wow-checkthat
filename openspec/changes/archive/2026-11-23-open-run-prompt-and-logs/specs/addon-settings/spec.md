## ADDED Requirements

### Requirement: Open run asks first while a run is active
Open run SHALL ask the player to accept before it opens a run when this character has an unfinished current run that is not the run chosen. The question SHALL say whether the current run leaves the checklist or stays. Without an active run, or for the current run itself, Open run SHALL ask nothing.

#### Scenario: Viewing an ended run
- **WHEN** the player chooses Open run for an ended run while a run is active
- **THEN** a question says the current run stays, and the run opens only after the player accepts

#### Scenario: Replacing a run
- **WHEN** the player chooses Open run for an unfinished run while another run is active
- **THEN** a question says the current run leaves the checklist, and nothing opens until the player accepts

#### Scenario: Nothing active
- **WHEN** this character has no unfinished current run
- **THEN** Open run opens the run without a question
