## MODIFIED Requirements

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

### Requirement: Verdict row and Run button fit the card
The verdict row SHALL hold Pass, Partial, Fail and Skip in fixed places, with Undo at the right. The secure button SHALL be labelled Run and SHALL sit inside the card beside the first command.

#### Scenario: Narrow card
- **WHEN** the card is at its default width
- **THEN** no button extends past its edge

### Requirement: Results screen leads back to the main window
The run-complete screen SHALL offer Export results and Main window. Main window SHALL return the floating card to its start screen, showing the finished run's plan with Start run and Import a plan, and SHALL NOT open the settings window. The screen SHALL NOT offer a Reload button. When the last step asked for a reload share point, its text SHALL tell the player to type `/reload`. Its text SHALL say the game saves evidence to disk when the player reloads or logs out.

#### Scenario: Back to start
- **WHEN** the run is complete and the player presses Main window
- **THEN** the card shows the plan ready with Start run and Import a plan, and no settings window opens

#### Scenario: Reload share point
- **WHEN** the last step asked for a reload share point and the run is complete
- **THEN** the results screen says to type `/reload` and shows no Reload button

## ADDED Requirements

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
The start screen SHALL stay at full card width even when the card is collapsed. Its text SHALL wrap inside the card. The first visible button SHALL sit at the left inset, so "Import a plan" takes the place of "Start run" when no plan is loaded.

#### Scenario: Long plan title
- **WHEN** a plan with a very long title is imported
- **THEN** the text stays inside the card and the first button is visible at the left inset
