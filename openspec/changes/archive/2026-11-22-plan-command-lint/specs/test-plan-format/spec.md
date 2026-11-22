# Spec Delta

## ADDED Requirements

### Requirement: Validation warns about unlisted slash commands
Validation SHALL warn, naming the step ID and command, when step action text names a slash command from the plan's allow list and the step's `commands` does not list it. Color codes in the text SHALL NOT hide the command. Warnings SHALL NOT fail validation or change its exit status.

#### Scenario: Colored command not listed
- **WHEN** a step's text contains a color-coded allowed slash command and `commands` is empty
- **THEN** validation prints a warning with the step ID and the command, and still succeeds

#### Scenario: Plain command not listed
- **WHEN** a step's text names an allowed slash command without color codes and `commands` lacks it
- **THEN** validation prints the same warning

#### Scenario: Command listed
- **WHEN** the step's `commands` lists the named command
- **THEN** validation prints no warning for it

#### Scenario: Copy-slash step
- **WHEN** a step's action is `copy-slash`, whose text is the command itself
- **THEN** validation prints no warning for it

#### Scenario: Command outside the allow list
- **WHEN** step text names a slash command not in the allow list
- **THEN** validation prints no warning for it
