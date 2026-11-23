## ADDED Requirements

### Requirement: Home lists past runs
The Home page SHALL list stored runs in a choice list, newest first, each with date, plan title, character and counts of pass, fail and open steps. Open, Export and Delete SHALL act on the chosen run. Delete SHALL ask for confirmation. Open SHALL ask for confirmation while the character has an unfinished run that it would replace on the card. Open SHALL be unavailable for an unfinished run of another character. The list and its buttons SHALL NOT draw when no runs are stored.

#### Scenario: Reopen an older run
- **WHEN** the player chooses Open on an ended run
- **THEN** the checklist window shows that run, read-only

#### Scenario: Export an older run
- **WHEN** the player chooses Export on a run
- **THEN** the text window shows that run's export string

#### Scenario: Unfinished run of another character
- **WHEN** the chosen run has not ended and belongs to another character
- **THEN** Open is unavailable and Export and Delete stay available

#### Scenario: Delete the current run
- **WHEN** the player deletes the current run and confirms
- **THEN** the run is gone and the checklist shows the start screen

### Requirement: Run limit setting
The Advanced page SHALL offer a run limit from 5 to 100 runs, with a default of 20, shared by all profiles. Lowering it SHALL prune at once. The debug report SHALL print its value.

#### Scenario: Report shows the limit
- **WHEN** the player runs /ct log
- **THEN** the report names the run limit and the number of stored runs and plans
