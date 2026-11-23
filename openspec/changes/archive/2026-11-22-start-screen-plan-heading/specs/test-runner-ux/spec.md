## MODIFIED Requirements

### Requirement: Import opens the window
Importing a valid plan SHALL open the checklist window and offer Start run and Import a plan. The heading SHALL be the plan title. The line under it SHALL give the step count, say the plan is ready to test, and tell the player to select Start run. A rejected import SHALL leave the window as it was and print the reason.

#### Scenario: Import success
- **WHEN** the player imports a valid plan
- **THEN** the window opens with the plan title as heading, the step count under it, and a Start run button

#### Scenario: One step
- **WHEN** the plan has exactly one step
- **THEN** the line under the heading says "1 step", not "1 steps"

### Requirement: Start screen layout
The start screen SHALL stay at full card width even when the card is collapsed. Its text SHALL wrap inside the card. A plan title longer than two lines SHALL be cut with the full title in the title tooltip. The first visible button SHALL sit at the left inset, so "Import a plan" takes the place of "Start run" when no plan is loaded. With no plan loaded the heading SHALL read "No plan yet" and the line under it SHALL tell the player to select Import a plan and paste a plan string.

#### Scenario: Long plan title
- **WHEN** a plan with a very long title is imported
- **THEN** the text stays inside the card, the full title shows in the tooltip, and the first button is visible at the left inset

#### Scenario: No plan
- **WHEN** no plan is loaded
- **THEN** the heading reads "No plan yet" and only Import a plan is offered
