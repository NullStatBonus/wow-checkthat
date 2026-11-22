## ADDED Requirements

### Requirement: The card says who checks the step
Under the step title the card SHALL show a banner. A step with at least one required assertion SHALL show "TESTTHAT CHECKS THIS STEP". Any other step SHALL show "YOU CONFIRM THIS STEP", and SHALL say whether TestThat records extra detail for the reviewer or cannot see the step.

#### Scenario: Auto-checked step
- **WHEN** a step has a required assertion
- **THEN** the green banner shows and the checks are listed below Expect

### Requirement: Live checks
While a step with required assertions is open, the card SHALL list each required check by its label and update the list at least twice a second: a green check when met, a waiting icon while not, a red mark when contradicted, and "(checked when you press Pass)" for absence checks. When all are met the card SHALL say so. Showing the list SHALL record nothing.

#### Scenario: Check ticks
- **WHEN** the awaited log line appears
- **THEN** the check turns green without any button press

### Requirement: Step navigation and redo
The card SHALL have < and > buttons, and `/wtt back` and `/wtt next` SHALL do the same. A step already recorded SHALL show what was recorded and its note, with a Redo button; Redo SHALL open a fresh attempt. After a result the card SHALL go to the next pending step, wrapping to earlier pending steps, and show the results screen only when nothing is pending. The results screen SHALL be reachable by > only when nothing is pending, and < SHALL leave it.

#### Scenario: Go back
- **WHEN** the tester presses < on step 3
- **THEN** step 2 shows what was recorded with a Redo button and no verdict buttons

#### Scenario: Redo
- **WHEN** the tester presses Redo
- **THEN** a fresh attempt opens and the verdict row returns
