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
The runner MAY show copy boxes for allowed commands, a button whose click is the player's hardware event, and a macro created or updated out of combat. It SHALL NOT offer a dedicated Reload button: a step that asks for a reload SHALL show the Run button beside its `/reload` command or tell the player to type `/reload`. It SHALL NOT send input, target, cast, loot, buy, sell, run unattended, or configure a secure button in combat; a deferred change SHALL apply when combat ends. The secure button SHALL be a separate top-level frame so the checklist card stays movable, resizable and hideable in combat.

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
- **WHEN** the player already has a macro named CT that the runner did not create
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

#### Scenario: Reload request
- **WHEN** a step asks for a reload
- **THEN** the card shows no Reload button, and its hint tells the player to type `/reload` or press Run where the step lists it

### Requirement: Auto-verification is read-only
Log assertions and state probes SHALL only read. Unverified results SHALL tell the player to retry or skip. Recording a result automatically SHALL change no game state and SHALL send no click, key, cast or command.

#### Scenario: Log matched
- **WHEN** the expected debug line appears after the action
- **THEN** the step records evidence matched when the player passes it

#### Scenario: Automatic result is bookkeeping only
- **WHEN** the runner records an automatic result
- **THEN** the only changes are in the run record, the card and the debug log

### Requirement: Notes and share points
The card SHALL offer a one-line note box saved with the verdict, shown behind an "Add note" control until the player opens it or the attempt already has a note. After a step with a share point, the card SHALL open the results export or ask for a reload so the log reaches the saved file. Unverified steps SHALL name the missing evidence and offer Retry or Skip with a note.

#### Scenario: Export share point
- **WHEN** the player records a verdict on a step with `share: export`
- **THEN** the results string opens in the copy window

#### Scenario: Note kept
- **WHEN** the player opens the note, types a note and presses Fail
- **THEN** the note is stored in the attempt and shown in the report

### Requirement: Import opens the window
Importing a valid plan SHALL open the checklist window and offer Start run and Import a plan. The heading SHALL be the plan title. The line under it SHALL give the step count, say the plan is ready to test, and tell the player to select Start run. A rejected import SHALL leave the window as it was and print the reason.

#### Scenario: Import success
- **WHEN** the player imports a valid plan
- **THEN** the window opens with the plan title as heading, the step count under it, and a Start run button

#### Scenario: One step
- **WHEN** the plan has exactly one step
- **THEN** the line under the heading says "1 step", not "1 steps"

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

### Requirement: Verdict row and Run button fit the card
The verdict row SHALL hold Pass, Partial, Fail and Skip in fixed places, with Undo at the right. The secure button SHALL be labelled Run and SHALL sit inside the card beside the first command.

#### Scenario: Narrow card
- **WHEN** the card is at its default width
- **THEN** no button extends past its edge

### Requirement: Reload is acknowledged
After a reload that resumes a step, the card SHALL say "Reloaded" in the hint line under Do and chat SHALL say the run continues on the same step.

#### Scenario: Resume
- **WHEN** the player reloads mid-step
- **THEN** the hint line says Reloaded and chat confirms the resume

### Requirement: Import screen offers recent plans
The import screen SHALL be titled "Import a plan" and SHALL offer a text box for a pasted plan string and a "Choose a plan" dropdown. The dropdown SHALL list "CheckThat self-test (built-in)" first, then up to 8 plans used before, newest first without duplicates. A recent entry for the built-in plan SHALL be left out. Choosing a recent plan SHALL make it the current plan, open the checklist window with Start run, and move it to the front of the list. A plan whose stored copy is gone SHALL be left out of the list.

#### Scenario: Pick a recent plan
- **WHEN** the player opens Import a plan and chooses a plan from the dropdown
- **THEN** the window opens with that plan ready and no string is pasted

#### Scenario: No history
- **WHEN** no plan was imported before
- **THEN** the dropdown lists only the built-in self-test

### Requirement: A new plan takes focus
Importing a plan, or choosing one from Recent plans, SHALL make it the pending plan. While a plan is pending the card SHALL show it with Start run, whether no run exists, the last run is complete, or a run is unfinished. With an unfinished run the card SHALL also offer Resume run; Resume SHALL return to that run unchanged. Starting a run SHALL clear the pending plan.

#### Scenario: Import after a finished run
- **WHEN** a run is complete and the player imports another plan
- **THEN** the card shows the new plan with Start run and no Resume

#### Scenario: Import during an unfinished run
- **WHEN** a run is unfinished and the player imports another plan
- **THEN** the card offers Start run and Resume run, and Resume returns to the unfinished run

### Requirement: The card says who checks the step
A step with at least one required assertion SHALL show its checks list under a small green "CheckThat checks" heading; an auto step's heading SHALL say that CheckThat records the result. A step without required assertions SHALL show no heading and no banner.

#### Scenario: Auto-checked step
- **WHEN** a step has a required assertion
- **THEN** the green heading shows above the checks list, under Expect

#### Scenario: Player step
- **WHEN** a step has no required assertion
- **THEN** no banner and no heading shows

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
The run-complete screen SHALL offer Export results and Main window. Main window SHALL return the floating card to its start screen, showing the finished run's plan with Start run and Import a plan, and SHALL NOT open the settings window. The screen SHALL NOT offer a Reload button. When the last step asked for a reload share point, its text SHALL tell the player to type `/reload`. Its text SHALL say the game saves evidence to disk when the player reloads or logs out.

#### Scenario: Back to start
- **WHEN** the run is complete and the player presses Main window
- **THEN** the card shows the plan ready with Start run and Import a plan, and no settings window opens

#### Scenario: Reload share point
- **WHEN** the last step asked for a reload share point and the run is complete
- **THEN** the results screen says to type `/reload` and shows no Reload button

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
- **THEN** the card pauses on the recorded step as for any result, with "Recorded by CheckThat"

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

### Requirement: The text window draws above the Run button
The copyable text windows (debug report, results string, plan import) SHALL draw above the card and above the secure Run button, so the button never shows over or through the window.

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

### Requirement: End run from the card
The card header SHALL offer a "Run" menu, in both the expanded and the collapsed card, with an "End run..." item. The menu SHALL use the game's context menu when it exists, then the older dropdown, then a plain button in the same place. Choosing End run SHALL ask for confirmation first, including when no step is resolved. The question SHALL say that recorded results are kept and that the run cannot resume. Escape or a missing dialog SHALL leave the run active.

#### Scenario: Player confirms
- **WHEN** a run is active and the player chooses End run and confirms
- **THEN** the run ends, the card shows "Run ended" with Export results and Main window, and Resume and Undo are not offered

#### Scenario: Player cancels
- **WHEN** the player chooses End run and presses Escape on the question
- **THEN** the run stays active and unchanged

#### Scenario: No steps resolved
- **WHEN** the player ends a run with every step pending
- **THEN** the question still appears

### Requirement: An ended run is read-only
An ended run SHALL keep every recorded verdict. Pending and unverified steps SHALL stay as they are, and progress SHALL count only resolved steps. The card SHALL NOT accept a verdict, Undo or Resume for it. Starting the plan again SHALL create a new run.

#### Scenario: Verdict on an ended run
- **WHEN** a run has ended and the player runs `/ct pass`
- **THEN** no verdict is recorded and a line says the run has ended

### Requirement: Card text stays inside the card
The card SHALL keep its title and header text inside the card width, in the expanded and the collapsed card. Text that does not fit SHALL end with an ellipsis. It SHALL NOT run past the card edge or over the card buttons. The collapsed card SHALL show the step title on one line and the full title on hover. The expanded card MAY use two lines.

#### Scenario: Long title in the collapsed card
- **WHEN** the card is collapsed during a run and the current step title is longer than the card width
- **THEN** the title shows on one line cut with an ellipsis, and hovering it shows the full title

#### Scenario: Long unbroken title
- **WHEN** a step title has a very long word with no spaces
- **THEN** the title still stays inside the card

### Requirement: Collapsed header layout
In the collapsed card the step counter SHALL sit immediately left of the collapse and close buttons. It SHALL NOT overlap the Run menu control. The counter SHALL show the current step and total while stepping, and resolved steps and total once the run has ended.

#### Scenario: Counter and menu
- **WHEN** the card is collapsed during a run
- **THEN** the Run menu control and the counter do not overlap, and a click on the control opens the menu

### Requirement: Run menu control
The card header SHALL show a visible "Run" control with a dropdown arrow and a hover highlight while a run is active. The whole control SHALL open the Run menu. The menu SHALL list "Import...", "End run..." and "Clear plan..." in that order. Where the game has no menu API, a click SHALL keep its direct End run question.

#### Scenario: Menu items
- **WHEN** a run is active and the player clicks the Run control
- **THEN** the menu shows Import, End run and Clear plan, in that order

### Requirement: Import from the Run menu
Choosing "Import..." SHALL open the same import box as the card's Import button, with the recent plans list. It SHALL NOT change the active run until a plan is imported or chosen.

#### Scenario: Import from the menu
- **WHEN** a run is active and the player chooses Import in the Run menu
- **THEN** the import box opens, and Escape leaves the run unchanged

### Requirement: Clear plan from the Run menu
Choosing "Clear plan..." SHALL ask for confirmation first. The question SHALL name the plan and say that the run ends, that recorded results stay exportable and that the plan leaves the loaded and recent plans. On confirmation the active run SHALL end as for End run and the plan SHALL be forgotten. Escape or a missing dialog SHALL change nothing.

#### Scenario: Player confirms
- **WHEN** a run is active and the player chooses Clear plan and confirms
- **THEN** the run ends, its results stay exportable, and the plan no longer shows as the loaded or recent plan

#### Scenario: Player cancels
- **WHEN** the player chooses Clear plan and presses Escape on the question
- **THEN** the run and the plan stay as they were

### Requirement: Ended screen after Clear plan
The ended-run screen SHALL keep "Export results" as its first button. When no plan is loaded, it SHALL offer "Import a plan" in place of "Main window". That button SHALL open the import box.

#### Scenario: Import after Clear plan
- **WHEN** the player cleared the plan and the ended screen shows
- **THEN** Export results comes first, and Import a plan opens the import box

### Requirement: Start screen layout
The start screen SHALL stay at full card width even when the card is collapsed. Its text SHALL wrap inside the card. A plan title longer than two lines SHALL be cut with the full title in the title tooltip. The first visible button SHALL sit at the left inset, so "Import a plan" takes the place of "Start run" when no plan is loaded. With no plan loaded the heading SHALL read "No plan yet" and the line under it SHALL tell the player to select Import a plan to try the built-in self-test or paste a plan string.

#### Scenario: Long plan title
- **WHEN** a plan with a very long title is imported
- **THEN** the text stays inside the card, the full title shows in the tooltip, and the first button is visible at the left inset

#### Scenario: No plan
- **WHEN** no plan is loaded
- **THEN** the heading reads "No plan yet" and only Import a plan is offered

### Requirement: The card shows a progress tracker
With two to eight categories the card SHALL show one segment per category in plan order, in the slot of the progress bar, and a caption under it. With one category it SHALL keep the plain bar. With more than eight it SHALL show one bar colored by the overall state. The count SHALL include unpicked categories. Content SHALL move down by the caption row only when the tracker shows.

#### Scenario: Four categories
- **WHEN** a plan has four categories
- **THEN** the card shows four segments and a caption

#### Scenario: Nine categories
- **WHEN** a plan has nine categories
- **THEN** the card shows one bar and the caption

#### Scenario: Collapsed
- **WHEN** the card is collapsed
- **THEN** the strip keeps the caption

### Requirement: The start flow offers categories
The Home page and the card start screen SHALL list each category of the chosen plan with a checkbox in plan order, all checked, with its step count. Start run SHALL be off, with a line saying why, when none is checked. A plan with one category SHALL show no list. The card start screen SHALL list up to eight categories inline. A plan with more SHALL show a Choose categories button that opens a window with the same checkboxes, fourteen rows at a time, scrolling with the mouse wheel and with page buttons. The Home page SHALL list twenty-four categories at a time with page buttons when the plan has more. Both lists SHALL change the same picked set.

#### Scenario: Pick two
- **WHEN** the tester clears two checkboxes and selects Start run
- **THEN** the run starts with the other categories picked

#### Scenario: None picked
- **WHEN** the tester clears every checkbox
- **THEN** Start run is off and a line says "Select at least one category."

#### Scenario: Thirty categories on the card
- **WHEN** a plan has thirty categories and the tester selects Choose categories
- **THEN** a window lists fourteen with page buttons, and a box cleared there is also cleared on Home

#### Scenario: Thirty categories on Home
- **WHEN** a plan has thirty categories
- **THEN** Home lists twenty-four, and Next page shows the other six

### Requirement: A Categories window lists every category
The card SHALL show a Categories control that opens a second movable window with one row per category: a colored square, the title, the state in words, and its passed, failed and open counts. The header SHALL show no overall count. It SHALL show up to 14 rows. A longer list SHALL scroll with the mouse wheel and with page buttons, and a line SHALL say which rows show. Each row SHALL show an arrow and the hint "Click for actions". Esc SHALL close the window.

#### Scenario: Many categories
- **WHEN** a plan has twelve categories
- **THEN** the window shows twelve rows, each with its color and state in words

#### Scenario: Long list
- **WHEN** a plan has twenty categories
- **THEN** the window shows fourteen, says which it shows, and the mouse wheel moves the list

### Requirement: A row in the Categories window offers add, go and rerun
A click on a row SHALL offer Add to run (not picked), Go to first open step (steps open), Rerun category (steps have results) and the other items of the row menu. Rerun SHALL ask first. Where the game has no menu API, or its menu fails, a click SHALL show a small list with one button per item, and no item SHALL run until the tester picks it. Picking an item, or pressing Esc, SHALL close the list. Esc SHALL close only the list while it shows, not the window behind it.

#### Scenario: Rerun from the window
- **WHEN** the tester chooses Rerun category on a green category and accepts
- **THEN** its steps reopen and the segment turns blue

#### Scenario: No menu
- **WHEN** the game has no menu API and the tester clicks a row of a category with results
- **THEN** a list shows every item of that row and none runs yet

#### Scenario: Pick one
- **WHEN** the tester picks an item in the list
- **THEN** that item runs and the list closes

#### Scenario: Esc with the list open
- **WHEN** the tester presses Esc while the list shows
- **THEN** the list closes and the Categories window stays open

### Requirement: The Categories window follows the card's appearance
The window SHALL keep its place, follow the card's opacity, draw nothing at zero background opacity, and reopen after a reload if it was open.

#### Scenario: Header
- **WHEN** the window is open during a run
- **THEN** its header shows the title and the buttons, and no overall count

#### Scenario: Esc
- **WHEN** the tester presses Esc with the window open
- **THEN** the window closes and stays closed after a reload

#### Scenario: Zero opacity
- **WHEN** the background opacity is zero
- **THEN** the window draws no fill or border

### Requirement: The card warns when errors cannot be seen
A step that reads the Lua error list SHALL show an amber line on the card while a run is open and nothing records errors (no handler of ours and no BugGrabber list). The line SHALL go when errors can be seen again.

#### Scenario: Blind
- **WHEN** a step with a no-error check is shown and nothing can see errors
- **THEN** the card shows an amber line saying CheckThat cannot detect new Lua errors

### Requirement: Verdicts have optional key bindings
The game's key bindings window SHALL list CheckThat actions for Pass, Partial, Fail and Skip, with no key assigned by default. Each action SHALL record the same result as its card button, with the note from the card. An action SHALL do nothing and say why when no run is active or the card is hidden. No binding SHALL send a protected action.

#### Scenario: Unbound by default
- **WHEN** the addon loads for the first time
- **THEN** no key triggers a verdict

#### Scenario: A bound key
- **WHEN** the tester presses a key bound to Pass on a step
- **THEN** the step passes as if Pass was clicked and the card shows the next step

#### Scenario: No run
- **WHEN** the tester presses a bound key with no active run
- **THEN** nothing is recorded and a line says there is no current step

### Requirement: The version command
`/ct version` SHALL print the CheckThat version. While a run is open and the version has the form major.minor.patch, it SHALL also report the fact `version` with the value major*10000 + minor*100 + patch. It SHALL take no arguments.

#### Scenario: Version during a run
- **WHEN** a run is open, the version is 0.17.0 and the tester types `/ct version`
- **THEN** chat shows "CheckThat 0.17.0" and the fact `[CheckThat] version=1700` is recorded

#### Scenario: No run
- **WHEN** no run is open and the tester types `/ct version`
- **THEN** chat shows the version and no fact is recorded

### Requirement: The CT macro can follow the current step
When the setting "Keep the CT macro on the current step" is on, CheckThat SHALL rewrite the CT macro each time the current step changes. The body SHALL be the line `/ct macrorun <step id>` followed by the step's commands, never a result command. A step with no usable commands SHALL get the marker and `/ct status`. CheckThat SHALL rewrite only a macro it made. A macro the player changed SHALL stay as it is for the rest of the run. A new run, or turning the setting on, SHALL take it back while its first line is still the marker, or while it holds only `/ct status`, the body CheckThat writes when no step is open. Bodies SHALL compare without trailing spaces or new lines, because the game can return a body with them.

#### Scenario: Step changes
- **WHEN** the setting is on, the tester is out of combat and the current step changes
- **THEN** the CT macro holds the marker for the new step, then the new step's commands

#### Scenario: Step without commands
- **WHEN** the new current step has no commands
- **THEN** the CT macro holds the marker, then `/ct status`

#### Scenario: No result command
- **WHEN** the macro is rewritten for any step
- **THEN** its body contains no `/ct pass`, `/ct partial`, `/ct fail` or `/ct skip`

#### Scenario: The player edited the macro
- **WHEN** the tester changed the body of the CT macro and the step changes
- **THEN** CheckThat does not edit that macro and does not claim it follows the step

#### Scenario: A new run takes the macro back
- **WHEN** the tester changed the macro in an earlier run, its first line is still the marker, and a new run shows its first step
- **THEN** the CT macro holds the marker and commands of that step

#### Scenario: The marker was removed
- **WHEN** the tester removed the marker line from the macro
- **THEN** CheckThat leaves the macro alone in every later run

#### Scenario: Setting off
- **WHEN** the setting is off and the step changes
- **THEN** the CT macro is not rewritten

#### Scenario: Macro left from an ended run
- **WHEN** the CT macro holds only `/ct status`, which CheckThat wrote after a run ended, and a new run shows its first step
- **THEN** the CT macro holds the marker and commands of that step

#### Scenario: Body read back with a trailing new line
- **WHEN** the game returns the CT macro body with a trailing new line and the step changes
- **THEN** CheckThat treats the macro as its own and rewrites it

### Requirement: A macro change waits for the end of combat
CheckThat SHALL NOT create or edit a macro in combat. A step change in combat SHALL queue one rewrite for the step that is current when combat ends.

#### Scenario: Step changes in combat
- **WHEN** the setting is on and the current step changes twice in combat
- **THEN** the macro is unchanged during combat and holds the latest step's commands after combat

### Requirement: The card says when a step has no macro
When the setting is on and the current step has commands that no macro can hold, the card SHALL show one line saying so. A step with no commands SHALL show no such line. The commands that fit are counted together with the marker line.

#### Scenario: Too many commands
- **WHEN** the current step lists more commands than the card offers, or the marker and the commands exceed the macro length limit
- **THEN** the macro holds the marker and `/ct status`, and the card line says the step has no macro

### Requirement: A macro rewrite is logged
Each rewrite SHALL log `macro set <step id>` in the debug log. When a rewrite fails, CheckThat SHALL log `macro not set <step id>: <reason>` once for each new reason, where the reason is `changed by the player`, `edit not taken`, `no free name` or `create failed`. When the game does not take an edit, chat SHALL say so once and tell the tester to delete the macro.

#### Scenario: Log line
- **WHEN** the macro is rewritten for step `ct.abc`
- **THEN** the debug log has the line `macro set ct.abc`

#### Scenario: The game does not take the edit
- **WHEN** the game leaves the CT macro unchanged after an edit, on two refreshes
- **THEN** the debug log has one line `macro not set <step id>: edit not taken` and chat has one line that names the fix

### Requirement: A macro press names its step
The body that `/ct macro` writes SHALL follow the same layout as the follow setting: the marker line first. The Run button SHALL NOT run the marker. When the marker runs, CheckThat SHALL tell a press for the current step from a press for another step, so a plan and a reviewer can see a macro pressed out of sync.

#### Scenario: Macro key on the current step
- **WHEN** the tester presses the macro key on the step the macro was written for
- **THEN** the debug log has `macro run <step id>`

#### Scenario: Macro key after the step moved
- **WHEN** the step moved in combat and the tester presses the macro key before the macro is rewritten
- **THEN** chat says the macro is for the old step and the card shows another, and the debug log has `macro stale <old id> card <current id>`

#### Scenario: Run button
- **WHEN** the tester clicks Run
- **THEN** the debug log has no `macro run` line

#### Scenario: Marker removed
- **WHEN** the tester removed the marker line from the macro and presses it
- **THEN** the debug log has no `macro run` or `macro stale` line

### Requirement: Listed actions are checkboxes the player ticks
When a step lists its actions, the card SHALL show one standard checkbox for each, with the action text as its label; a click on the box or the label toggles it. Where the checkbox template is missing, the card SHALL show a clickable text row with "[ ]" or "[x]". A finished step SHALL show its ticks read-only. Ticks SHALL NOT enable, disable or record a result.

#### Scenario: Tick an action
- **WHEN** the player clicks the label of the second action
- **THEN** its box is ticked and the attempt saves the tick

#### Scenario: Pass with an action unticked
- **WHEN** the player presses Pass with one action unticked
- **THEN** the step is judged as today

### Requirement: The card pauses on every result
When a result is recorded, by the player or by CheckThat, and the run moves on while the card is shown and expanded, the card SHALL keep the recorded step on screen for 3 seconds and fade to the next step. An unverified result SHALL NOT pause the card. A result press during the pause SHALL be ignored with a chat line.

#### Scenario: Double press
- **WHEN** the player presses Pass twice in quick succession
- **THEN** the first press records the step, the second is ignored with a chat line, and the next step has no result

#### Scenario: Last step
- **WHEN** the player records the last step
- **THEN** the card pauses on its result and then shows Run complete

### Requirement: The paused card shows the result simply
While the card pauses, it SHALL show only the step title, the result as one large word in its color ("Passed" green, "Partial" amber, "Failed" red, "Skipped" grey), "Recorded by you" or "Recorded by CheckThat", and the note.

#### Scenario: Player presses Fail
- **WHEN** the player types a note and presses Fail on a step with listed actions
- **THEN** the card shows the step title, "Failed" in red and "Recorded by you" with the note, without Do, Expect or the checkboxes

### Requirement: A result cue marks each pause
Each pause SHALL call one result cue with the verdict and who recorded it, so a sound can be added there later.

#### Scenario: Result cue
- **WHEN** a pause starts
- **THEN** the result cue runs once with the verdict and `player` or `auto`

### Requirement: The start screen lists what a plan reads
Under the step count, the start screen SHALL list the globals that the plan's log sources, `global-value` checks and `frame-text` checks read, sorted, at most six and then "and N more", with the sentence that a results string can include what they hold. A plan that reads none SHALL show no line. A `frame-shown` check SHALL NOT be listed. Names SHALL be cut to 40 characters with `|` doubled.

#### Scenario: A plan that reads a log
- **WHEN** a plan with a log source on `KeepThatDB` is ready to start
- **THEN** the start screen says "This plan reads these variables: KeepThatDB. A results string can include what they hold."

#### Scenario: A plan that reads a frame's text
- **WHEN** a plan has a `frame-text` check on `MerchantFrame`
- **THEN** the list names `MerchantFrame`

#### Scenario: A plan that reads nothing
- **WHEN** a plan has no log source, no `global-value` check and no `frame-text` check
- **THEN** the start screen shows no such line

### Requirement: A profile switch moves the Categories window
When the profile changes, is copied or is reset, the card and the Categories window SHALL take their place and look from the new profile at once.

#### Scenario: Switch profile
- **WHEN** the player switches to a profile that has no saved place for the Categories window
- **THEN** the window moves to its default place with no reload

### Requirement: Built-in self-test
CheckThat SHALL ship the compiled `plans/selftest.yaml` and a test SHALL fail when the shipped string differs from it. Choosing "CheckThat self-test (built-in)" SHALL import that string through the same checks as a pasted string, without showing it in the box, and open the checklist window with Start run. Importing it again SHALL reuse its stored copy. Nothing outside the import window SHALL offer it: no popup, no login message, no first-run prompt.

#### Scenario: Fresh install
- **WHEN** a player with no plan opens Import a plan and chooses the self-test
- **THEN** the window opens with "CheckThat self-test" and Start run, and no string was pasted

#### Scenario: Run in progress
- **WHEN** a run is unfinished and the player chooses the self-test
- **THEN** the card offers Start run and Resume run, and Resume returns to the unfinished run

### Requirement: The card shows a step's cleanup
After a step has a pass, partial, fail or skip result, the card SHALL show the step's `cleanup` text: under the result while the card holds it, and at the top of the next step until that step has a result. A reload SHALL keep it. Undo or Redo of that step, or another run, SHALL hide it.

#### Scenario: Pass moves on
- **WHEN** a step with cleanup gets Fail and the card shows the next step
- **THEN** the next step starts with "First, after the last step:" and the cleanup text

#### Scenario: Next step recorded
- **WHEN** the next step gets a result
- **THEN** the cleanup line is gone

### Requirement: The import window uses the AceGUI frame
When AceGUI is loaded, the import window SHALL open in the AceGUI frame with the "Choose a plan" dropdown and the Import button. The plain window SHALL open only when AceGUI is missing or fails, and the debug log SHALL say why.

#### Scenario: AceGUI loaded
- **WHEN** the player opens Import a plan
- **THEN** the AceGUI frame opens and the log has no `import window: plain window` line
