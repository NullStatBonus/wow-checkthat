## ADDED Requirements

### Requirement: A read-only viewer browses the evidence
`ct.py browse` (and `tools/ct_tui.py`) SHALL open a read-only terminal viewer with a runs screen (failures first, then unverified, newest first), a steps screen in plan order that can be narrowed by result and category, and a step screen that shows the classified result and the player's verdict first, then one attempt with its note, checks, log lines and error stacks. It SHALL show evidence as plain text.

#### Scenario: Failing runs first
- **WHEN** the viewer opens over a failing run, an unverified run and a passing run
- **THEN** the runs screen lists them in that order

### Requirement: The viewer follows the evidence folder
The viewer SHALL reload when the evidence folder changes, SHALL keep the selected item by id, and SHALL keep the newest readable revision of a run that is being written.

#### Scenario: A reload keeps the selection
- **WHEN** the evidence changes so the selected run moves to another row
- **THEN** the cursor stays on that run

### Requirement: The viewer needs a terminal and says so
Without a terminal or without Textual, the viewer SHALL exit 2 and print the equivalent commands or the install command. It SHALL check for a terminal before it imports Textual.

#### Scenario: No terminal
- **WHEN** the viewer starts with its output redirected
- **THEN** it prints the `status`, `report --failed-only` and `show` commands and exits 2

### Requirement: The viewer exports after it shows what it will write
The viewer SHALL show the scope, format, file and whether stacks are included before it writes a report, and SHALL leave stacks out of a JSON or JUnit export unless the user adds them.

#### Scenario: Stacks are opt-in
- **WHEN** the export dialog is set to JSON and the user has not asked for stacks
- **THEN** it says the stacks are left out and the file holds none
