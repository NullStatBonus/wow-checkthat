# debug-tools Specification

## Purpose
The bounded debug log, the copyable report and the adapter rule for game calls.

## Requirements

### Requirement: Bounded debug log
While recording is on the addon SHALL keep the last 300 lines as `[area] message` entries with a time in saved variables, and SHALL record nothing when it is off. Failures that turn something off SHALL be recorded even when recording is off.

#### Scenario: Off
- **WHEN** recording is off
- **THEN** no lines are added

### Requirement: Copyable report
`/ct log` SHALL open a window with a selectable report: addon version, client, build, every saved setting, the current run status, failures, then the recorded lines. The window SHALL be the standard AceGUI frame with a scrolling read-only text box, the same as KeepThat, DontDoThat and ClosestVendor.

#### Scenario: Copy
- **WHEN** the report opens
- **THEN** its text is selected-all ready for Ctrl+C

#### Scenario: Same window as the sibling addons
- **WHEN** the report opens
- **THEN** it shows a title bar, the status line "Press Ctrl+A to select everything, then Ctrl+C to copy." and a text box that ignores typing

#### Scenario: AceGUI missing
- **WHEN** the AceGUI frame is not available
- **THEN** the report opens in the plain CheckThat text window instead

### Requirement: Game calls go through the adapter
Every game API read and action SHALL be in `Core/Adapter.lua`, guarded, returning nil when missing. Model code SHALL use no game globals. Frame construction, anchoring and styling in `UI/` and `Debug/` MAY call the game directly. Other modules SHALL NOT.

#### Scenario: Missing API
- **WHEN** a game function does not exist
- **THEN** the adapter returns nil and no Lua error is raised

#### Scenario: UI builds its own frames
- **WHEN** a file in `UI/` or `Debug/` calls `CreateFrame` or reads `UIParent`
- **THEN** the layering test passes

#### Scenario: Game global outside the allowed places
- **WHEN** a file in `Model/`, `Options/` or `Core/` other than the adapter uses a game global
- **THEN** the layering test fails and names the file

### Requirement: One cause writes one log line
The debug log SHALL NOT repeat the same line while the cause stays the same. When the game shows the Run button on a screen with nothing to run, CheckThat SHALL hide it and write one `run button hidden` line for that screen.

#### Scenario: The game shows the button again and again
- **WHEN** the game shows the Run button five times in a row on a step without commands
- **THEN** the debug log holds one `run button hidden` line for that step

#### Scenario: The next screen
- **WHEN** the card moves to another step without commands and the game shows the button
- **THEN** the debug log holds a new `run button hidden` line for that step

### Requirement: The log names questions, exports and reports
The debug log SHALL hold `run open asked <id>` when Open run asks, `run delete asked <id>` when Delete run asks, `run exported <id>` when CheckThat builds a results string, and `report requested: <Stored line>` when the debug report is built.

#### Scenario: Question cancelled
- **WHEN** the player chooses Open run and cancels the question
- **THEN** the log holds `run open asked` and no `run opened` line for it

#### Scenario: Report built
- **WHEN** the player types `/ct log`
- **THEN** the log holds `report requested: Stored: <n> runs (limit <n>), <n> plan copies`

### Requirement: The Run button leaves the combat state driver while unused
CheckThat SHALL release the Run button from the game's combat state driver out of combat while the step has nothing to run, and SHALL register it again when a step has commands. A line `run button hidden` SHALL be written once for each screen.

#### Scenario: A step without commands
- **WHEN** the card shows a step that has no commands and the player is out of combat
- **THEN** the Run button is hidden and released from the state driver, and the log holds at most one `run button hidden` line for the step

### Requirement: The report shows the newest error stack
The `/ct log` report SHALL show the newest kept error stack on a `Last error stack:` line, and no such line when none is kept.

#### Scenario: A stack is kept
- **WHEN** an error kept a stack
- **THEN** the report holds a `Last error stack:` line with it

### Requirement: The report lists what the plan reads
While a run is on the card, the debug report SHALL hold a line `Plan reads: <names>` with every global the plan's log sources and `global-value` checks read, or `Plan reads: none`. With no run the line is absent.

#### Scenario: Plan with a log source
- **WHEN** the plan of the run on the card has a log source on `KeepThatDB`
- **THEN** the report holds `Plan reads: KeepThatDB`
