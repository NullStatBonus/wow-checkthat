## MODIFIED Requirements

### Requirement: The text window draws above the Run button
The copyable text windows (debug report, results string, plan import) SHALL draw above the card and above the secure Run button, so the button never shows over or through the window.

#### Scenario: Export from a step with a Run button
- **WHEN** the player opens the results string while a step with a Run button is showing
- **THEN** the window covers the Run button and the button cannot be clicked through it

#### Scenario: Debug report
- **WHEN** the player opens the debug report from the card or the settings window
- **THEN** the window draws above every CheckThat frame
