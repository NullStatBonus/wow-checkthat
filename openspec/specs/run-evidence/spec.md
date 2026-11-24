# run-evidence Specification

## Purpose
How runs, attempts, verdicts and evidence are recorded, kept across reload, and collected outside the game.

## Requirements

### Requirement: Runs are recorded with identity
Each run SHALL record run ID, revision, plan digest, client, client build, character, and per-step attempts with verdict (pass, fail, skip, unverified, plus pending and inapplicable steps), timestamps, assertion outcomes, claimed verdict, and notes. Every change SHALL bump the revision.

#### Scenario: Retry
- **WHEN** a step fails and is retried
- **THEN** a new attempt is recorded and the earlier attempt is kept

### Requirement: A pass needs its evidence
A claimed pass SHALL record as pass only if every required (non-diagnostic) assertion passes. Contradicting evidence SHALL record fail. Missing, unreadable, ambiguous, or rolled-over evidence SHALL record unverified and keep the step open. Diagnostic assertions SHALL be recorded without gating. Evidence SHALL be labelled matched only when at least one required assertion exists and all required assertions passed; a step whose assertions are all diagnostic SHALL be labelled diagnostic-only. A log assertion SHALL read only lines added after the attempt opened unless its scope is session. The attempt boundary SHALL be found by position in the log; if it cannot be located unambiguously the result is unverified. An absent assertion SHALL pass only when the window holds at least one new line.

#### Scenario: Missing log line
- **WHEN** the player claims pass and the required line is absent
- **THEN** the attempt records unverified with the claim retained

#### Scenario: Stale line
- **WHEN** the expected line exists only from before the attempt opened
- **THEN** the assertion is unverified

#### Scenario: Absence
- **WHEN** an assertion requires a line to be absent and it appears
- **THEN** the attempt records fail

#### Scenario: Absence with debug off
- **WHEN** no new log lines arrived during the attempt
- **THEN** an absent assertion is unverified, not pass

#### Scenario: Diagnostic only
- **WHEN** a step's assertions are all diagnostic and the player passes it
- **THEN** the attempt records pass with evidence diagnostic-only

#### Scenario: Repeated startup block
- **WHEN** the same startup lines appear in every session of the log and the player reloads mid-step
- **THEN** only lines after the snapshot position count as new

### Requirement: Results survive reload
The runner SHALL keep the run in SavedVariables (`CheckThatDB.global.runs`), open an attempt before the player acts, keep that attempt (with its log snapshot) across `/reload`, resume the current step after login, and offer an immediate export string. Results SHALL be labelled "saved on reload" until the game flushes them. The runner's own log SHALL be readable as an evidence source at `CheckThatDB.global.log.entries`.

#### Scenario: Reload mid-step
- **WHEN** a step has `reload: after_action` and the player reloads
- **THEN** the same attempt is current after login and verifies against the log lines written during load

### Requirement: Reviewer-only evidence is preserved
Where a plan names reviewer-only evidence, exports SHALL retain the exact reviewer instruction and the recorded outcome.

#### Scenario: Reviewer step
- **WHEN** a step has `reviewer` text
- **THEN** the report lists it with the step

### Requirement: External scripts collect evidence centrally
Provided scripts SHALL copy CT and tested-addon SavedVariables from a WTF or saved-copy directory into one central directory, deduplicating by content hash and by run ID plus revision, convert SavedVariables and results strings to JSON, and write a readable report of every non-passing step. Scripts SHALL NOT modify game files.

#### Scenario: Duplicate collection
- **WHEN** the script runs twice with no new reload
- **THEN** the central directory has one copy per file and one file per run revision

### Requirement: Runs are bound to their plan and character
A run SHALL resolve its steps from the exact plan version (digest) it started with, even after a newer import. The active run SHALL be tracked per character and realm; another character SHALL not resume or read evidence for it.

#### Scenario: Reimport during a run
- **WHEN** a plan with changed step IDs is imported while a run is active
- **THEN** the active run keeps using the plan it started with

#### Scenario: Character switch
- **WHEN** another character logs in
- **THEN** it has no active run from the first character

### Requirement: Undo follows commit order
Undo SHALL revert the most recent verdict in the order verdicts were committed and drop any retry attempt opened after it.

#### Scenario: Undo after fail
- **WHEN** a step fails, a retry opens, and the player presses Undo
- **THEN** the failed verdict and the open retry are removed and earlier steps are untouched

### Requirement: Screenshots are collected by time window
A step MAY ask for a screenshot taken by the player with the game's own key. The collector SHALL copy screenshot files whose modification time falls inside an attempt's window into that run's folder, and the report SHALL list them under the step. The runner SHALL NOT capture screenshots itself.

#### Scenario: Screenshot in window
- **WHEN** a screenshot file was written during a step's attempt
- **THEN** collect copies it under the run and the report names it for that step

### Requirement: Partial verdict
A step MAY be recorded as partial, meaning it mostly works. A partial claim SHALL be gated by required evidence exactly like a pass: matched evidence records partial, contradicting evidence records fail, missing evidence records unverified. A partial step SHALL advance the run like a pass, SHALL be counted separately, and SHALL be listed in the report with its note.

#### Scenario: Partial with evidence
- **WHEN** the player records partial with a note and the required evidence matched
- **THEN** the attempt records partial with the note and the run moves to the next step

#### Scenario: Partial without evidence
- **WHEN** the player records partial and required evidence is missing
- **THEN** the attempt records unverified and the step stays open

### Requirement: Fail moves on
A fail result SHALL move the run to the next pending step, like pass, partial and skip. Only an unverified result SHALL keep the step open. Undo SHALL reopen a failed step.

#### Scenario: Fail on the last step
- **WHEN** the tester records fail on the last pending step
- **THEN** the run is complete and shows the results

### Requirement: Missing evidence is explained in the log
When a result is recorded with a missing or contradicting required check, the log line SHALL end with the reason.

#### Scenario: Unverified
- **WHEN** a pass is recorded without the awaited line
- **THEN** the log reads "step <id> unverified evidence unverified: <reason>"

### Requirement: An auto step records its own pass
While an auto step has an open attempt, the runner SHALL re-read the required assertions at least twice a second, whether or not the card is shown. When every required assertion is met, the runner SHALL record the pass by the same evidence gate as a player's pass, with the claim labelled `auto`, and SHALL move to the next pending step. Reading and recording SHALL send no input and SHALL start no game action.

#### Scenario: Hidden card
- **WHEN** the awaited log line appears while an auto step is open and the card is hidden
- **THEN** the step records pass with evidence matched and claim auto, and the next step is current

#### Scenario: Line appears
- **WHEN** the awaited log line appears while an auto step is open
- **THEN** the step records pass with evidence matched and claim auto, without a button press

#### Scenario: Not all met
- **WHEN** one of two required assertions is met and the other is waiting
- **THEN** the step stays open and records nothing

#### Scenario: Player clicks first
- **WHEN** the player records fail on an auto step before its checks are met
- **THEN** the step records the player's result and the runner does not record another

#### Scenario: Undo
- **WHEN** the player undoes an automatic pass or any later result of the step
- **THEN** the step reopens and the runner can settle it again

#### Scenario: Reload requested
- **WHEN** an auto step asks for a reload after the action and its checks are met before the reload happened
- **THEN** the runner waits for the reload, and the timeout still settles the step

#### Scenario: Check changes between reads
- **WHEN** a check reads met on the card refresh but not when the runner records the result
- **THEN** the runner records nothing and tries again on the next refresh

### Requirement: An auto step settles at its timeout
When an auto step has a timeout and that many seconds have passed since its attempt opened with the checks not all met, the runner SHALL settle the step once, as an automatic pass claim through the evidence gate. A contradicted required assertion SHALL record fail. Missing, unreadable or rolled-over evidence SHALL record unverified and keep the step open. The step SHALL NOT fail only because a check read bad earlier and recovered before the timeout.

#### Scenario: Contradicting evidence at timeout
- **WHEN** the timeout passes and a required state check still reads wrong
- **THEN** the step records fail with evidence contradicts and claim auto

#### Scenario: Missing evidence at timeout
- **WHEN** the timeout passes and the awaited line never appeared
- **THEN** the step records unverified and stays open

#### Scenario: Recovery before timeout
- **WHEN** a required check reads bad and then reads met before the timeout
- **THEN** the step records pass

#### Scenario: Reload keeps the clock
- **WHEN** the player reloads the interface while an auto step is open
- **THEN** the timeout still counts from the time the attempt opened

### Requirement: An automatic result is settled once and labelled
The runner SHALL settle an auto attempt at most once. After an automatic unverified result the card opens the retry attempt as it does for any unverified step, but the runner SHALL NOT settle that attempt or any later one until the player acts. The attempt, the debug log line, the results string and the report SHALL show that the runner settled it, also while a retry is open.

#### Scenario: No loop of automatic results
- **WHEN** an auto step records unverified at its timeout and the retry attempt is open
- **THEN** the runner records no further automatic result until the player acts

#### Scenario: Reviewer can tell
- **WHEN** a reviewer reads the report for an automatic result, including while a retry attempt is open
- **THEN** the report labels the result as recorded by CheckThat, not by the player

### Requirement: Ended runs stay recorded
Ending a run SHALL set an optional run-level `endedAt` time and bump the revision once. The end SHALL keep every step record, attempt and note. Exports, the saved run and the debug report SHALL mark the run ended, even when every recorded verdict is pass. An ended run SHALL accept no verdict, Undo, auto-settle or reload resume. A saved run without `endedAt` SHALL read as not ended.

#### Scenario: Ended run exported
- **WHEN** a player ends a run with 3 of 8 steps resolved and exports it
- **THEN** the export holds the 3 verdicts, the 5 steps as they were, and the ended time

#### Scenario: Reload after end
- **WHEN** the player reloads after ending a run
- **THEN** the run is still ended and no step resumes

### Requirement: Attempts snapshot only the logs a step checks
When a step opens an attempt, CheckThat SHALL record a position in each log source that an attempt-scoped log or log-sequence assertion of that step names, and in no other log. A position SHALL hold the log length and its last 12 lines. A log source that a step does not check MUST NOT be recorded for that step.

#### Scenario: Unchecked log is not recorded
- **WHEN** a plan declares logs "debug" and "other" and a step checks only "debug"
- **THEN** the attempt of that step holds a position for "debug" and none for "other"

#### Scenario: Session-scope assertion needs no position
- **WHEN** a step's only log assertion has session scope
- **THEN** the attempt records no log position

### Requirement: A log without a position is never all new
When an attempt-scoped assertion names a log source that has no position in the attempt, the check SHALL give "unverified" and MUST NOT count the whole log as new lines.

#### Scenario: Missing position
- **WHEN** an attempt lacks a position for the asserted source and the log holds a matching line
- **THEN** the check does not pass and the note says the log position is missing

### Requirement: An absence is not shown after the log rolled
When the boundary of an attempt was found by search and the saved tail is not distinctive (fewer than half of its lines differ), a check that a line is absent SHALL be unverified when the new lines hold no such line, and SHALL fail when one does. When the tail is distinctive, the boundary SHALL count as exact and an absence check SHALL be judged on the new lines. Checks for a present line SHALL be judged as before.

#### Scenario: Rolled log
- **WHEN** a ring log rolled over so far that lines near the boundary may be missing
- **THEN** an absence check does not pass

#### Scenario: Flooded tail
- **WHEN** a ring log rolled and the saved tail is one repeated line
- **THEN** an absence check does not pass

#### Scenario: Full ring with a distinctive tail
- **WHEN** a full ring log pushed old lines out and the saved tail is found once
- **THEN** an absence check passes when no new line matches, and fails when one does

### Requirement: Older full snapshots stay usable
A run saved with full-array snapshots SHALL keep checking correctly after an update.

#### Scenario: Old run after update
- **WHEN** an open attempt holds a full-array snapshot
- **THEN** its new lines are found as before

### Requirement: Unused plan copies are pruned
CheckThat SHALL delete a stored plan copy that no stored run, no loaded plan and no recent-list entry names. Pruning SHALL run when a plan is imported, a plan is cleared or a run is deleted.

#### Scenario: Orphan after Clear plan
- **WHEN** a plan was imported twice with different content and only one revision has a run
- **THEN** the other revision is deleted at the next import or clear

#### Scenario: Run keeps its plan
- **WHEN** a stored run names a plan copy
- **THEN** that copy stays, even when it is not loaded

### Requirement: Old runs are pruned to a limit
CheckThat SHALL keep at most the configured number of runs, newest first, and MUST NOT delete the current run of any character.

#### Scenario: Limit reached
- **WHEN** a new run starts and the limit is exceeded
- **THEN** the oldest non-current run is deleted and its plan copy follows the pruning rule

### Requirement: The report lists every step
The central report (`ct.py report`) SHALL print, for each run, a `result:` line (ok, UNVERIFIED or FAIL with counts) and a table with one row per step in plan order: step id, verdict, evidence state, attempt count and note. Detail lines for attempts and evidence SHALL stay for steps that did not pass. A step that passed after a failed or unverified attempt SHALL list those attempts too.

#### Scenario: Passing step with evidence
- **WHEN** a run holds a step that passed through a log assertion
- **THEN** the table has a row for it with verdict pass, evidence state met and its attempt count

#### Scenario: Passing step without evidence
- **WHEN** a step passed on the player's click alone
- **THEN** the row shows evidence state none and the step has no detail lines

#### Scenario: Failing step keeps its detail
- **WHEN** a step failed
- **THEN** the table has a row and the attempt and evidence detail lines follow as before

#### Scenario: Unverified evidence
- **WHEN** a step has an assertion outcome that is unverified or has no result
- **THEN** its row shows evidence state missing

#### Scenario: A pass after a rerun
- **WHEN** a step failed once and passed on its second attempt
- **THEN** the report lists the failed attempt under the step

### Requirement: Fact assertions are judged on parsed values
A fact assertion SHALL read the facts of the named addon and key that arrived since the attempt opened. A value SHALL be a boolean for `true` and `false`, a number when it reads as one, else text. With no matching fact the result SHALL be unverified. With facts that break the operator the result SHALL be fail. `which: last` judges the newest fact, `any` passes when one matches, and `all` passes when every one matches.

#### Scenario: Value out of range
- **WHEN** a step needs `between [1, 5]` and the fact `level=9` arrives
- **THEN** the assertion fails and the step cannot pass

#### Scenario: Fact never arrives
- **WHEN** no fact with the key arrives
- **THEN** the assertion is unverified, not failed

#### Scenario: Number as text
- **WHEN** the fact reads `name=abc` and the assertion is `type number`
- **THEN** the assertion fails

#### Scenario: Approximate value
- **WHEN** a step needs `approx 0.5` with tolerance 0.01 and the fact reads 0.504
- **THEN** the assertion passes

### Requirement: Counts judge how many lines matched
With `count`, the result SHALL pass when the number of matching new lines fits. More than the maximum SHALL fail. Fewer than the minimum SHALL be unverified, as the line can still arrive. A count that allows zero SHALL need a readable log whose boundary is known, like an absence check.

#### Scenario: Too many, shown at once
- **WHEN** a step needs exactly two reports and a third arrives
- **THEN** the card shows the check as failed at once, not only when the result is recorded

#### Scenario: Called twice
- **WHEN** a step needs `exactly 2` and two matching lines arrive
- **THEN** the assertion passes

#### Scenario: Called three times
- **WHEN** a step needs `exactly 2` and three matching lines arrive
- **THEN** the assertion fails

#### Scenario: Called once
- **WHEN** a step needs `min 2` and one line has arrived
- **THEN** the assertion is unverified

### Requirement: Silence on a quiet source is a result
On a quiet source, an absence check or a count that allows zero SHALL pass when the log is readable, its boundary is known and no matching line arrived. An unreadable source SHALL stay unverified with the reason shown.

#### Scenario: No Lua errors
- **WHEN** a step needs no line on the quiet error source and none arrived
- **THEN** the assertion passes

#### Scenario: Source unreadable
- **WHEN** the plan's quiet source cannot be read
- **THEN** the assertion is unverified and says the source cannot be read

#### Scenario: Error expected
- **WHEN** a step needs one line matching a pattern on the error source and it arrived
- **THEN** the assertion passes

### Requirement: Lua errors are recorded while a run is open
While a run is open, CheckThat SHALL record each Lua error as one line in a bounded list in its saved variables, with the message cut to 200 characters, a rate limit like facts, and a debug log line. It SHALL pass every error on to the handler that was set before it and SHALL NOT raise errors itself. Plans read the list as a quiet log source. No error SHALL be recorded when no run is open.

#### Scenario: Error during a step
- **WHEN** an addon raises a Lua error while a run is open
- **THEN** a line with its message is added, the earlier handler still receives the error, and a step that needs no error line fails

#### Scenario: No run
- **WHEN** an error occurs with no run open
- **THEN** nothing is recorded

#### Scenario: Flood
- **WHEN** an addon raises hundreds of errors in one second
- **THEN** only the rate limit's worth are kept and one debug line says the rest were dropped

#### Scenario: Handler replaced
- **WHEN** another addon replaced the error handler after CheckThat set its own
- **THEN** CheckThat sets its handler again when a run starts or a category is triggered

#### Scenario: Handler slot held by BugGrabber
- **WHEN** BugGrabber holds the handler slot and makes setting a handler do nothing
- **THEN** the debug report shows the handler as blocked, and CheckThat records a line for each rise of a BugGrabber error counter, also for an error that was already in its list

#### Scenario: Error before the step
- **WHEN** an error counted by BugGrabber happened before a step opened
- **THEN** it does not count against that step

#### Scenario: Nothing is recording
- **WHEN** no handler is set, BugGrabber is not loaded, and the tester records a result on a step that needs no Lua error
- **THEN** CheckThat records a line that says it cannot see errors, and the step does not pass on silence

#### Scenario: Earlier handler raises
- **WHEN** the handler set before CheckThat's raises an error
- **THEN** CheckThat records the error, says so in the debug log, and raises nothing in the game's handler

### Requirement: Recorded errors name their addon and keep a stack
Each recorded Lua error line SHALL read `<time>.<counter> [<addon>] <message>`, where the addon is the name in `AddOns\<Name>\` in the message, `?` when there is none, and `CheckThat` for lines CheckThat adds. The first error of each step SHALL keep its call stack on one line in a second saved list, cut to 600 characters, never with locals. When another addon takes the error handler during a run, CheckThat SHALL set its own again, at most once a second.

#### Scenario: Two addons
- **WHEN** errors from two addons are recorded
- **THEN** each line carries its own addon name and a check can match one of them

#### Scenario: One stack for a step
- **WHEN** a step records two errors
- **THEN** one stack is kept, and the next step keeps one again

#### Scenario: A taken handler
- **WHEN** another addon replaces the handler during a run
- **THEN** CheckThat sets its own again within a second, and a flood of replacements logs only a few lines

### Requirement: A failed attempt keeps the log lines that arrived
When an attempt records fail or unverified, it SHALL keep, for each log its step checks (not `session` scope), the first 20 new lines, each cut to 200 characters, as `excerpt`. A pass SHALL keep none. A log that cannot be read, or whose start is lost, SHALL add none. A run SHALL keep at most about 60 000 bytes of excerpt lines: when it holds more, the attempts that finished earliest lose their excerpt first. The results string SHALL stay version 1. The report SHALL print the lines under the attempt.

#### Scenario: A failure
- **WHEN** a step fails after 30 new log lines
- **THEN** its attempt holds the first 20, each at most 200 characters, and the report prints them

#### Scenario: A pass
- **WHEN** a step passes
- **THEN** its attempt holds no excerpt

#### Scenario: Over the budget
- **WHEN** the excerpts of a run exceed the budget
- **THEN** the oldest attempts lose theirs and the newest keep them

### Requirement: One error stack for each attempt
CheckThat SHALL ask for an error stack only when a step opens a new attempt, not when the card refreshes an attempt that is already open.

#### Scenario: Card refresh
- **WHEN** the card refreshes a step whose attempt is open
- **THEN** no second stack is requested

### Requirement: The report shows error stacks
`collect` SHALL keep the saved error lines and call stacks. The report SHALL print, under a failed or unverified attempt, each error whose `<time>.<counter>` key falls in the attempt's open time, with its stack, and SHALL say when the time also fits another attempt. Json and junit reports SHALL leave stacks out unless asked.

#### Scenario: A stack in the window
- **WHEN** an error with a stack was raised while a failed attempt was open
- **THEN** the report prints the error and its stack under that attempt

#### Scenario: Stacks stay private by default
- **WHEN** a json or junit report is made without `--stacks`
- **THEN** it holds no stack text

### Requirement: The report has machine-readable formats
`ct.py report` SHALL support `--format json` and `--format junit`, and `--strict`. One rule SHALL classify each step for every format: a pass or partial claim with a failed required outcome is a fail, one with a required outcome without a result is unverified. Fail and unverified are failures in JUnit; pending, skip, deselected and inapplicable are skipped with a reason; partial passes. `--strict` SHALL exit 1 when any step failed or is unverified, or no run exists.

#### Scenario: CI gate
- **WHEN** `report --format junit --strict` runs over a run with a failed step
- **THEN** the XML holds a failure for that step and the exit code is 1

### Requirement: Status checks the evidence folder
`ct.py status` SHALL print one row for each run at its newest readable revision (steps done over steps that apply, fail, unverified and open counts, age, estimated export size), and SHALL name every unreadable revision, every conflict or decode failure `collect` logged, and any run over 80% of the 2 MB export limit. It SHALL exit 1 when it names a problem or finds no run, and SHALL NOT judge test results.

#### Scenario: A damaged revision
- **WHEN** the newest revision file of a run is not valid JSON
- **THEN** status names it, still shows the newest readable revision and exits 1

#### Scenario: A clean folder
- **WHEN** every revision is readable and nothing conflicts
- **THEN** status says there are no problems and exits 0

### Requirement: Open-attempt snapshots are not a conflict
`collect` and `import-results` SHALL compare two stored copies of one run revision as an export would hold them. Copies that differ only by open-attempt snapshots SHALL NOT conflict.

#### Scenario: Collected, then imported
- **WHEN** a revision is collected from saved variables and the same revision is imported from `/ct export`
- **THEN** the second store reports the same revision, not a conflict

### Requirement: The report can be narrowed and one step shown
`ct.py report --failed-only` SHALL keep only the runs and steps that failed or are unverified, by the same rule as `--strict`, and say when there are none. `ct.py show <run>` SHALL print one run as the report does, and `ct.py show <run> <step>` SHALL print that step with every attempt, log excerpt and error stack. A run name SHALL be an exact id or part of an id that names one run. An unknown or unclear run or step SHALL exit 2 and list the choices.

#### Scenario: One step with its history
- **WHEN** `show R-1 a` runs for a step that failed once and then passed
- **THEN** both attempts print and no other step does

#### Scenario: An unclear name
- **WHEN** `show` names a step the run does not have
- **THEN** it exits 2 and lists the run's steps

### Requirement: Status can be watched
`ct.py status --watch` SHALL print the status again every `--interval` seconds until interrupted, and SHALL return the exit code of the last status. It SHALL NOT combine with `--json`.

#### Scenario: Two rounds
- **WHEN** the watch runs two rounds over a healthy folder
- **THEN** it prints twice and returns 0

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

### Requirement: The viewer's runs and steps screens show state in words and marks
The viewer SHALL show each run's and step's state as a word and a mark (color only helps), SHALL count each run once with fail before unverified and call the rest "no flags", and SHALL show steps done over steps that apply. Below 76 columns the screens SHALL show only the result, the id and (for runs) the done fraction; from 76 columns they SHALL add the other columns. A category chip SHALL follow the evidence-based result of its steps. A filter with no match SHALL say so.

#### Scenario: A narrow terminal
- **WHEN** the terminal is 40 columns wide
- **THEN** the runs table has the result, run and done columns, and a resize to 100 columns brings back plan, revision, counts and age

#### Scenario: An overturned pass
- **WHEN** a step's pass is contradicted by its required evidence
- **THEN** its category chip is red, not green
