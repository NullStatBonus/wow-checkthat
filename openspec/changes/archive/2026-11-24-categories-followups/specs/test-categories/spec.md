# Spec Delta

## ADDED Requirements

### Requirement: A category row expands to its steps
Each row of the Categories window SHALL have an expand control. An expanded row SHALL be followed by one indented row per step of the category in plan order, including steps of an unpicked category and steps not for this client, each with the step's result in words and a mark so color is never the only cue. Rows start collapsed and stay as the tester left them while the run stays on the card. Each expand or collapse SHALL write a debug log line.

#### Scenario: Expand a failed category
- **WHEN** the tester expands a category with one failed step
- **THEN** the steps list under it and the failed one reads "failed" with its mark

### Requirement: Step rows count in the paging
Paging SHALL count step rows like category rows and keep the window's row limit.

#### Scenario: Long list
- **WHEN** expanding rows makes the list longer than the window
- **THEN** the window keeps its row limit and the paging text counts all rows

### Requirement: A step row shows its step
A click on a step row SHALL show that step on the card and SHALL change no result and no pick. A step that is not offered (not picked, not for this client) SHALL show in the list but a click on it SHALL do nothing. On an ended run a click SHALL still show the step.

#### Scenario: Go to a step
- **WHEN** the tester clicks a step row of a picked category
- **THEN** the card shows that step and the run's results do not change

#### Scenario: Unpicked category
- **WHEN** a category is not picked and the tester expands it
- **THEN** its steps read "not picked" and a click on one does nothing and does not pick the category

#### Scenario: Step with the name of a category
- **WHEN** a step has the same id as a category and the tester clicks its row
- **THEN** the card shows that step
