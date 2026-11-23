# Spec Delta

## ADDED Requirements

### Requirement: The text window draws above the Run button
The copyable text window (debug report, results string, plan import) SHALL draw above the card and above the secure Run button, so the button never shows over or through the window.

#### Scenario: Export from a step with a Run button
- **WHEN** the player opens the results string while a step with a Run button is showing
- **THEN** the window covers the Run button and the button cannot be clicked through it

#### Scenario: Debug report
- **WHEN** the player opens the debug report from the card or the settings window
- **THEN** the window draws above every CheckThat frame

### Requirement: The Run button shows only with a step that has commands
The secure Run button SHALL be visible only while the card shows an open step that has commands, and SHALL be hidden on the results screen, on the Start screen and while the card is hidden. When anything else shows it out of combat, the card SHALL hide it again and SHALL write one debug log line saying so. The card SHALL NOT change the button in combat.

#### Scenario: Results screen
- **WHEN** the run is complete and the results screen shows, and the game shows the Run button again
- **THEN** the card hides the Run button at once and the debug log says it was hidden

#### Scenario: Step with commands
- **WHEN** the card shows a step that has commands
- **THEN** the Run button is visible and the guard does not hide it

#### Scenario: Combat
- **WHEN** the button is shown while the player is in combat
- **THEN** the card does not touch it
