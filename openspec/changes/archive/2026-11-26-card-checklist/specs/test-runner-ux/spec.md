## MODIFIED Requirements

### Requirement: Card layout hierarchy
The card SHALL show, top to bottom: a header with the current step number and the close and collapse controls; a thin progress bar filled by resolved steps; the step title as the strongest text, heavier than any other text on the card; a Setup line (when the step has setup, or a preamble or section intro applies) that folds; Do, as a sentence or as one checkbox for each listed action, with the step's commands in read-only boxes and the Run button next to the first; Expect, as a sentence or one short line for each listed result; the checks list under a small "CheckThat checks" heading when the step has required assertions; an amber evidence line only when evidence is missing; an "Add note" control; and a pinned row with Pass, Partial, Fail, Skip and Undo. Collapsed, the card SHALL be a one-line strip with the step title and the step number.

#### Scenario: Unverified step
- **WHEN** a Pass has missing required evidence
- **THEN** the card stays on the step, keeps Do and Expect visible, and shows an amber line with the reason and one recovery action

#### Scenario: Run complete
- **WHEN** the last step is resolved
- **THEN** the card shows passed, failed and skipped counts, the plan's handoff text, and Export results and Main window buttons

#### Scenario: Setup fold
- **WHEN** a step with setup opens for the first time in the run
- **THEN** the Setup fold is open; on a later visit it shows one line that opens on a click

### Requirement: The card says who checks the step
A step with at least one required assertion SHALL show its checks list under a small green "CheckThat checks" heading; an auto step's heading SHALL say that CheckThat records the result. A step without required assertions SHALL show no heading and no banner.

#### Scenario: Auto-checked step
- **WHEN** a step has a required assertion
- **THEN** the green heading shows above the checks list, under Expect

#### Scenario: Player step
- **WHEN** a step has no required assertion
- **THEN** no banner and no heading shows

### Requirement: Notes and share points
The card SHALL offer a one-line note box saved with the verdict, shown behind an "Add note" control until the player opens it or the attempt already has a note. After a step with a share point, the card SHALL open the results export or ask for a reload so the log reaches the saved file. Unverified steps SHALL name the missing evidence and offer Retry or Skip with a note.

#### Scenario: Export share point
- **WHEN** the player records a verdict on a step with `share: export`
- **THEN** the results string opens in the copy window

#### Scenario: Note kept
- **WHEN** the player opens the note, types a note and presses Fail
- **THEN** the note is stored in the attempt and shown in the report

### Requirement: Reload is acknowledged
After a reload that resumes a step, the card SHALL say "Reloaded" in the hint line under Do and chat SHALL say the run continues on the same step.

#### Scenario: Resume
- **WHEN** the player reloads mid-step
- **THEN** the hint line says Reloaded and chat confirms the resume

### Requirement: The card says a step settles itself
An auto step SHALL show on the card that CheckThat records the result when the checks are met. When it has a timeout, the card SHALL show the seconds left, counted from when the attempt opened. A `wait-event` step SHALL show what it is waiting for in words the player understands. The player SHALL still see Pass, Fail, Partial, Skip and Undo.

#### Scenario: Waiting
- **WHEN** an auto step is open with checks not met
- **THEN** the card says CheckThat records the result when the checks are met

#### Scenario: Countdown
- **WHEN** an auto step has a 30 second timeout and 12 seconds have passed
- **THEN** the card shows 18 seconds left

#### Scenario: Result recorded
- **WHEN** the runner records an automatic pass, partial or fail while the card is shown and expanded and the run moves on
- **THEN** the card keeps the recorded step on screen with "Recorded: Pass (recorded by CheckThat)" and fades to the next step over 3 seconds

#### Scenario: Unverified at the timeout
- **WHEN** an automatic result is unverified and the step stays open
- **THEN** the card does not pause and the player's next press counts

#### Scenario: Run ended during the fade
- **WHEN** the run ends while the card holds a result
- **THEN** the card shows the ended run at once

#### Scenario: Press during the fade
- **WHEN** the player presses a card button or a result key during the fade
- **THEN** the fade ends at once and the press applies to the next step only if it is a navigation press; a result press is ignored with a chat line

#### Scenario: Card hidden
- **WHEN** the card is hidden while an auto step is open and the checks are met
- **THEN** the runner records the result, and the card shows the next step, without a fade, when the player opens it again

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

## ADDED Requirements

### Requirement: Listed actions are checkboxes the player ticks
When a step lists its actions, the card SHALL show one standard checkbox for each, with the action text as its label; a click on the box or the label toggles it. Where the checkbox template is missing, the card SHALL show a clickable text row with "[ ]" or "[x]". A finished step SHALL show its ticks read-only. Ticks SHALL NOT enable, disable or record a result.

#### Scenario: Tick an action
- **WHEN** the player clicks the label of the second action
- **THEN** its box is ticked and the attempt saves the tick

#### Scenario: Pass with an action unticked
- **WHEN** the player presses Pass with one action unticked
- **THEN** the step is judged as today
