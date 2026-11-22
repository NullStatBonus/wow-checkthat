## ADDED Requirements

### Requirement: Verdict row and Run button fit the card
The verdict row SHALL hold Pass, Partial, Fail and Skip in fixed places, with Reload (only when asked for) and Undo at the right. The secure button SHALL be labelled Run and SHALL sit inside the card beside the first command.

#### Scenario: Narrow card
- **WHEN** the card is at its default width
- **THEN** no button extends past its edge

### Requirement: Reload is acknowledged
After a reload that resumes a step, the card SHALL show a visible "Reloaded" line under the step title and chat SHALL say the run continues on the same step.

#### Scenario: Resume
- **WHEN** the player reloads mid-step
- **THEN** the card shows the Reloaded line and chat confirms the resume
