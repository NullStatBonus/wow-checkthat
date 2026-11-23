# Spec Delta

## MODIFIED Requirements

### Requirement: The card says who checks the step
Under the step title the card SHALL show a banner. A step with at least one required assertion SHALL show "CHECKTHAT CHECKS THIS STEP". Any other step SHALL show "YOU CONFIRM THIS STEP", and SHALL say whether CheckThat records extra detail for the reviewer or cannot see the step.

#### Scenario: Auto-checked step
- **WHEN** a step has a required assertion
- **THEN** the green banner shows and the checks are listed below Expect

### Requirement: Step navigation and redo
The card SHALL have < and > buttons, and `/ct back` and `/ct next` SHALL do the same. A step already recorded SHALL show what was recorded and its note, with a Redo button; Redo SHALL open a fresh attempt. After a result the card SHALL go to the next open step, wrapping to earlier open steps, and show the results screen only when nothing is open. A step that stayed unverified is open. The results screen SHALL be reachable by > only when nothing is pending, and < SHALL leave it.

#### Scenario: Go back
- **WHEN** the tester presses < on step 3
- **THEN** step 2 shows what was recorded with a Redo button and no verdict buttons

#### Scenario: Redo
- **WHEN** the tester presses Redo
- **THEN** a fresh attempt opens and the verdict row returns

### Requirement: The card says a step settles itself
An auto step SHALL show on the card that CheckThat records the result when the checks are met. When it has a timeout, the card SHALL show the seconds left, counted from when the attempt opened. A `wait-event` step SHALL show what it is waiting for in words the player understands. The player SHALL still see Pass, Fail, Partial, Skip and Undo.

#### Scenario: Waiting
- **WHEN** an auto step is open with checks not met
- **THEN** the card says CheckThat records the result when the checks are met

#### Scenario: Countdown
- **WHEN** an auto step has a 30 second timeout and 12 seconds have passed
- **THEN** the card shows 18 seconds left

#### Scenario: Result recorded
- **WHEN** the runner records an automatic result
- **THEN** the card moves to the next step and the recorded step shows that CheckThat settled it

#### Scenario: Card hidden
- **WHEN** the card is hidden while an auto step is open
- **THEN** the runner records nothing until the card is shown again

#### Scenario: Game interface hidden
- **WHEN** the player hides the game interface while an auto step is open
- **THEN** the runner records nothing until the interface is shown again

#### Scenario: Start screen showing
- **WHEN** the card shows the Start screen of a newly imported plan while an old run has an open auto step
- **THEN** the runner records nothing for the old run until the player returns to it

#### Scenario: Typed note
- **WHEN** the player typed a note and the runner records the result before a button is pressed
- **THEN** the result keeps the note and the note box is cleared

#### Scenario: Combat
- **WHEN** the runner records a result during combat
- **THEN** the card redraws without changing the secure Run button, which is set up after combat
