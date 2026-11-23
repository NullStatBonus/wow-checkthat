## ADDED Requirements

### Requirement: The log names questions, exports and reports
The debug log SHALL hold `run open asked <id>` when Open run asks, `run delete asked <id>` when Delete run asks, `run exported <id>` when CheckThat builds a results string, and `report requested: <Stored line>` when the debug report is built.

#### Scenario: Question cancelled
- **WHEN** the player chooses Open run and cancels the question
- **THEN** the log holds `run open asked` and no `run opened` line for it

#### Scenario: Report built
- **WHEN** the player types `/ct log`
- **THEN** the log holds `report requested: Stored: <n> runs (limit <n>), <n> plan copies`

### Requirement: The Run button leaves the combat state driver while unused
CheckThat SHALL release the Run button from the game's combat state driver out of combat while the step has nothing to run, and SHALL register it again when a step has commands. A line `run button hidden` SHALL be written once for each screen.

#### Scenario: A step without commands
- **WHEN** the card shows a step that has no commands and the player is out of combat
- **THEN** the Run button is hidden and released from the state driver, and the log holds at most one `run button hidden` line for the step
