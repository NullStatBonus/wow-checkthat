## ADDED Requirements

### Requirement: One cause writes one log line
The debug log SHALL NOT repeat the same line while the cause stays the same. When the game shows the Run button on a screen with nothing to run, CheckThat SHALL hide it and write one `run button hidden` line for that screen.

#### Scenario: The game shows the button again and again
- **WHEN** the game shows the Run button five times in a row on a step without commands
- **THEN** the debug log holds one `run button hidden` line for that step

#### Scenario: The next screen
- **WHEN** the card moves to another step without commands and the game shows the button
- **THEN** the debug log holds a new `run button hidden` line for that step
