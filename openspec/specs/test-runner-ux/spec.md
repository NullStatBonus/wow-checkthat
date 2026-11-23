# test-runner-ux Specification

## Purpose
What the in-game checklist shows and may do, within the game terms of service.

## Requirements

### Requirement: One step at a time, never in the way
The runner SHALL show a movable, collapsible card with the current step's setup, action, exact expected result, what happens next, progress, and fixed-position Pass, Fail, Skip and Undo controls. The attempt and evidence capture SHALL arm when the step appears, before the player acts. The card SHALL remember its position and current step across reload.

#### Scenario: Position kept
- **WHEN** the player reloads
- **THEN** the card keeps its position and current step

### Requirement: Prerequisites surfaced
The runner SHALL show unmet requirements of the current step as blocked and SHALL mark steps for the other client as inapplicable, excluded from progress.

#### Scenario: Wrong client
- **WHEN** a step lists only `forever-camelot` and the client is Classic Era
- **THEN** it is inapplicable and never offered

### Requirement: Action assistance stays player-driven
The runner MAY show copy boxes for allowed commands, a button whose click is the player's hardware event, a macro created or updated out of combat, and a Reload button. It SHALL NOT send input, target, cast, loot, buy, sell, run unattended, or configure a secure button in combat; a deferred change SHALL apply when combat ends. The secure button SHALL be a separate top-level frame so the checklist card stays movable, resizable and hideable in combat.

#### Scenario: Secure button
- **WHEN** a step offers a macro
- **THEN** it runs only when the player clicks

#### Scenario: Combat
- **WHEN** the player is in combat as a step changes
- **THEN** the secure button is hidden for the whole of combat, is never built or changed in combat, and is set up again for the current step when combat ends

#### Scenario: Card in combat
- **WHEN** the player drags or collapses the card in combat
- **THEN** no protected-action block occurs

#### Scenario: Existing macro
- **WHEN** the player already has a macro named WTT that the runner did not create
- **THEN** the runner leaves it alone and creates the macro under an unused name

#### Scenario: Too many commands
- **WHEN** a step lists more commands than the card has copy boxes
- **THEN** the card offers no Run button, so no command runs unseen

#### Scenario: Note stays with its step
- **WHEN** the player types a note and moves to another step
- **THEN** the note box is empty on the other step

#### Scenario: Manual step with commands
- **WHEN** a manual step lists commands and every command is on the allow list
- **THEN** the card offers the Run button, which runs the commands in order when the player clicks

#### Scenario: Copy boxes
- **WHEN** a step offers a multi-line macro
- **THEN** each command shows in its own read-only box, and typing, cutting or deleting reverts

#### Scenario: After reload
- **WHEN** the player returns from a reload mid-step
- **THEN** the card asks them to check the result, not to reload again

### Requirement: Auto-verification is read-only
Log assertions and state probes SHALL only read. Unverified results SHALL tell the player to retry or skip. Recording a result automatically SHALL change no game state and SHALL send no click, key, cast or command.

#### Scenario: Log matched
- **WHEN** the expected debug line appears after the action
- **THEN** the step records evidence matched when the player passes it

#### Scenario: Automatic result is bookkeeping only
- **WHEN** the runner records an automatic result
- **THEN** the only changes are in the run record, the card and the debug log

### Requirement: Notes and share points
The card SHALL offer a one-line note box saved with the verdict. After a step with a share point, the card SHALL open the results export or ask for a reload so the log reaches the saved file. Unverified steps SHALL name the missing evidence and offer Retry or Skip with a note.

#### Scenario: Export share point
- **WHEN** the player records a verdict on a step with `share: export`
- **THEN** the results string opens in the copy window

#### Scenario: Note kept
- **WHEN** the player types a note and presses Fail
- **THEN** the note is stored in the attempt and shown in the report

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
- **THEN** the card shows passed, failed and skipped counts, the plan's handoff text, and Export results and Main window buttons

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

### Requirement: Import screen offers recent plans
The import screen SHALL offer a text box for a pasted plan string and a "Recent plans" dropdown of up to 8 plans used before, newest first without duplicates. Choosing one SHALL make it the current plan, open the checklist window with Start run, and move it to the front of the list. A plan whose stored copy is gone SHALL be left out of the list.

#### Scenario: Pick a recent plan
- **WHEN** the player opens Import a plan and chooses a plan from the dropdown
- **THEN** the window opens with that plan ready and no string is pasted

#### Scenario: No history
- **WHEN** no plan was imported before
- **THEN** the dropdown button is disabled and says there are no recent plans

### Requirement: A new plan takes focus
Importing a plan, or choosing one from Recent plans, SHALL make it the pending plan. While a plan is pending the card SHALL show it with Start run, whether no run exists, the last run is complete, or a run is unfinished. With an unfinished run the card SHALL also offer Resume run; Resume SHALL return to that run unchanged. Starting a run SHALL clear the pending plan.

#### Scenario: Import after a finished run
- **WHEN** a run is complete and the player imports another plan
- **THEN** the card shows the new plan with Start run and no Resume

#### Scenario: Import during an unfinished run
- **WHEN** a run is unfinished and the player imports another plan
- **THEN** the card offers Start run and Resume run, and Resume returns to the unfinished run

### Requirement: The card says who checks the step
Under the step title the card SHALL show a banner. A step with at least one required assertion SHALL show "CHECKTHAT CHECKS THIS STEP". Any other step SHALL show "YOU CONFIRM THIS STEP", and SHALL say whether CheckThat records extra detail for the reviewer or cannot see the step.

#### Scenario: Auto-checked step
- **WHEN** a step has a required assertion
- **THEN** the green banner shows and the checks are listed below Expect

### Requirement: Live checks
While a step with required assertions is open, the card SHALL list each required check by its label and update the list at least twice a second: a green check when met, a waiting icon while not, a red mark when contradicted, and "(checked when you press Pass)" for absence checks. When all are met the card SHALL say so. Showing the list SHALL record nothing.

#### Scenario: Check ticks
- **WHEN** the awaited log line appears
- **THEN** the check turns green without any button press

### Requirement: Step navigation and redo
The card SHALL have < and > buttons, and `/ct back` and `/ct next` SHALL do the same. A step already recorded SHALL show what was recorded and its note, with a Redo button; Redo SHALL open a fresh attempt. After a result the card SHALL go to the next open step, wrapping to earlier open steps, and show the results screen only when nothing is open. A step that stayed unverified is open. The results screen SHALL be reachable by > only when nothing is pending, and < SHALL leave it.

#### Scenario: Go back
- **WHEN** the tester presses < on step 3
- **THEN** step 2 shows what was recorded with a Redo button and no verdict buttons

#### Scenario: Redo
- **WHEN** the tester presses Redo
- **THEN** a fresh attempt opens and the verdict row returns

### Requirement: Results screen leads back to the main window
The run-complete screen SHALL offer Export results and Main window. Main window SHALL return the floating card to its start screen, showing the finished run's plan with Start run and Import a plan, and SHALL NOT open the settings window. The screen SHALL NOT offer Reload unless the last step asked for a reload share point; its text SHALL say the game saves evidence to disk when the player reloads or logs out.

#### Scenario: Back to start
- **WHEN** the run is complete and the player presses Main window
- **THEN** the card shows the plan ready with Start run and Import a plan, and no settings window opens

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

### Requirement: The text window draws above the Run button
The copyable text window (debug report, results string, plan import) SHALL draw above the card and above the secure Run button, so the button never shows over or through the window.

#### Scenario: Export from a step with a Run button
- **WHEN** the player opens the results string while a step with a Run button is showing
- **THEN** the window covers the Run button and the button cannot be clicked through it

#### Scenario: Debug report
- **WHEN** the player opens the debug report from the card or the settings window
- **THEN** the window draws above every CheckThat frame

### Requirement: The Run button shows only with a step that has commands
The secure Run button SHALL be visible only while the card shows an open step that has commands, and SHALL be hidden on the results screen, on the Start screen and while the card is hidden. When anything else shows it out of combat, the card SHALL hide it again and SHALL write one debug log line saying so. The card SHALL NOT change the button in combat.

#### Scenario: Results screen
- **WHEN** the run is complete and the results screen shows, and the game shows the Run button again
- **THEN** the card hides the Run button at once and the debug log says it was hidden

#### Scenario: Step with commands
- **WHEN** the card shows a step that has commands
- **THEN** the Run button is visible and the guard does not hide it

#### Scenario: Combat
- **WHEN** the button is shown while the player is in combat
- **THEN** the card does not touch it
