## MODIFIED Requirements

### Requirement: Import screen offers recent plans
The import screen SHALL be titled "Import a plan" and SHALL offer a text box for a pasted plan string and a "Choose a plan" dropdown. The dropdown SHALL list "CheckThat self-test (built-in)" first, then up to 8 plans used before, newest first without duplicates. A recent entry for the built-in plan SHALL be left out. Choosing a recent plan SHALL make it the current plan, open the checklist window with Start run, and move it to the front of the list. A plan whose stored copy is gone SHALL be left out of the list.

#### Scenario: Pick a recent plan
- **WHEN** the player opens Import a plan and chooses a plan from the dropdown
- **THEN** the window opens with that plan ready and no string is pasted

#### Scenario: No history
- **WHEN** no plan was imported before
- **THEN** the dropdown lists only the built-in self-test

### Requirement: Start screen layout
The start screen SHALL stay at full card width even when the card is collapsed. Its text SHALL wrap inside the card. A plan title longer than two lines SHALL be cut with the full title in the title tooltip. The first visible button SHALL sit at the left inset, so "Import a plan" takes the place of "Start run" when no plan is loaded. With no plan loaded the heading SHALL read "No plan yet" and the line under it SHALL tell the player to select Import a plan to try the built-in self-test or paste a plan string.

#### Scenario: Long plan title
- **WHEN** a plan with a very long title is imported
- **THEN** the text stays inside the card, the full title shows in the tooltip, and the first button is visible at the left inset

#### Scenario: No plan
- **WHEN** no plan is loaded
- **THEN** the heading reads "No plan yet" and only Import a plan is offered

## ADDED Requirements

### Requirement: Built-in self-test
CheckThat SHALL ship the compiled `plans/selftest.yaml` and a test SHALL fail when the shipped string differs from it. Choosing "CheckThat self-test (built-in)" SHALL import that string through the same checks as a pasted string, without showing it in the box, and open the checklist window with Start run. Importing it again SHALL reuse its stored copy. Nothing outside the import window SHALL offer it: no popup, no login message, no first-run prompt.

#### Scenario: Fresh install
- **WHEN** a player with no plan opens Import a plan and chooses the self-test
- **THEN** the window opens with "CheckThat self-test" and Start run, and no string was pasted

#### Scenario: Run in progress
- **WHEN** a run is unfinished and the player chooses the self-test
- **THEN** the card offers Start run and Resume run, and Resume returns to the unfinished run
