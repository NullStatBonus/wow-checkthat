## ADDED Requirements

### Requirement: Import opens the window
Importing a valid plan SHALL open the checklist window, show the plan title and step count, and offer Start run and Import a plan. A rejected import SHALL leave the window as it was and print the reason.

#### Scenario: Import success
- **WHEN** the player imports a valid plan
- **THEN** the window opens with the plan ready and a Start run button

### Requirement: Card layout hierarchy
The card SHALL show, top to bottom: a header with the current step number and the close and collapse controls; a thin progress bar filled by resolved steps; the step title as the strongest text; Setup (when given), Do and Expect in a labelled column; the commands of the step in read-only boxes beside Do with the Run all button next to the first; an amber evidence line only when evidence is missing; a labelled note field; and a pinned row with Pass, Fail, Skip and Undo. Collapsed, the card SHALL be a one-line strip with the step title and the step number.

#### Scenario: Unverified step
- **WHEN** a Pass has missing required evidence
- **THEN** the card stays on the step, keeps Do and Expect visible, and shows an amber line with the reason and one recovery action

#### Scenario: Run complete
- **WHEN** the last step is resolved
- **THEN** the card shows passed, failed and skipped counts, the plan's handoff text, and Export results and Reload buttons
