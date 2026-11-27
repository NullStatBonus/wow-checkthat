## MODIFIED Requirements

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

## ADDED Requirements

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
