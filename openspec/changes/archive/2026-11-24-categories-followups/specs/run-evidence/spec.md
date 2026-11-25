# Spec Delta

## MODIFIED Requirements

### Requirement: Screenshots are collected by time window
A step MAY ask for a screenshot taken by the player with the game's own key. The collector SHALL copy screenshot files whose modification time falls inside an attempt's window into that run's folder, and the report SHALL list them under the step. The runner SHALL NOT capture screenshots itself. The collector SHALL also count the screenshot files that fall inside no window but within one hour of an attempt, and SHALL say so in its summary on every collect, also when the matched files were copied earlier. With `--verbose` it SHALL name each such file with the nearest attempt and the gap in seconds. With `--all-shots` it SHALL copy them to `unassigned-shots/` in the folder of the nearest run, and no step SHALL list them.

#### Scenario: Screenshot in window
- **WHEN** a screenshot file was written during a step's attempt
- **THEN** collect copies it under the run and the report names it for that step

#### Scenario: Screenshot outside every window
- **WHEN** a screenshot file was written 13 minutes after the last attempt closed
- **THEN** collect copies nothing for it and its summary says one screenshot matched no attempt

#### Scenario: Old screenshots stay out
- **WHEN** the screenshot folder holds files from days before any run
- **THEN** the summary does not count them

#### Scenario: Second collect
- **WHEN** collect runs twice and a screenshot in a window was copied by the first
- **THEN** the second summary counts it as matched, not as unmatched

#### Scenario: Verbose names the gap
- **WHEN** the same collect runs with `--verbose`
- **THEN** the output names the file, the nearest attempt and the gap in seconds

#### Scenario: Keep unmatched files
- **WHEN** the same collect runs with `--all-shots`
- **THEN** the file is copied under `unassigned-shots/` and no step lists it

### Requirement: A reopened step shows no old evidence
After Undo or a rerun reopens a step that had a result, the step SHALL carry `reopened` in its saved record until an attempt finishes or the step leaves the run. The report table, json and junit reports SHALL show a pending step that is flagged, or that holds a finished attempt, as "awaiting retry" with evidence `none`, not the earlier attempt's note and evidence. This holds also when Undo removed the step's only attempt. A step that is not pending SHALL ignore the flag. A run saved before the marker existed SHALL still show "awaiting retry" for a pending step that holds a finished attempt.

#### Scenario: Rerun
- **WHEN** a step with a failed attempt with bad evidence is reopened
- **THEN** the table shows awaiting retry and evidence none, and the earlier attempt stays in the export

#### Scenario: Undo of the only attempt
- **WHEN** the tester undoes the only verdict of a step
- **THEN** the step holds no finished attempt, its record says `reopened`, and the table shows awaiting retry

#### Scenario: Untouched steps in a rerun
- **WHEN** a category rerun reopens two steps and a third step never had a result
- **THEN** only the two are flagged and the third reads as before

#### Scenario: Removed from the run
- **WHEN** a reopened step's category is removed from the run
- **THEN** the flag is gone and the step is not shown as awaiting retry

#### Scenario: Retry finishes
- **WHEN** a reopened step gets a new verdict
- **THEN** the marker is gone and the table shows the new verdict

#### Scenario: Machine reports
- **WHEN** the json or junit report covers a reopened step
- **THEN** it gives the same "awaiting retry" reason as the table

#### Scenario: Run from 0.16.0
- **WHEN** the tools read a run with no `reopened` key and a pending step with a finished attempt
- **THEN** the table shows awaiting retry as before
