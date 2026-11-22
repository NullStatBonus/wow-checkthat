## ADDED Requirements

### Requirement: Import screen offers recent plans
The import screen SHALL offer a text box for a pasted plan string and a "Recent plans" dropdown of up to 8 plans used before, newest first without duplicates. Choosing one SHALL make it the current plan, open the checklist window with Start run, and move it to the front of the list. A plan whose stored copy is gone SHALL be left out of the list.

#### Scenario: Pick a recent plan
- **WHEN** the player opens Import a plan and chooses a plan from the dropdown
- **THEN** the window opens with that plan ready and no string is pasted

#### Scenario: No history
- **WHEN** no plan was imported before
- **THEN** the dropdown button is disabled and says there are no recent plans
