# slash-interface Specification

## Purpose
The /ct command vocabulary and the validated settings keys.

## Requirements

### Requirement: Common command vocabulary
`/ct` SHALL open the checklist. `settings [page]`, `help [topic]`, `status [topic]`, `get <key>`, `set <key> <value>`, `debug on|off`, `log` and `log clear` SHALL behave as in the sibling addons. Runner commands SHALL be `import`, `start <addon>`, `end`, `pass|fail|skip [note]`, `undo`, `export`, `macro` and `reload`. `end` SHALL use the same confirmation and code path as End run on the card.

#### Scenario: Help topics
- **WHEN** the player runs `/ct help diagnostics`
- **THEN** the debug and log commands are listed

#### Scenario: End with confirmation
- **WHEN** a run is active and the player runs `/ct end` and confirms
- **THEN** the run ends exactly as from the card menu

#### Scenario: End with no run
- **WHEN** no run is active and the player runs `/ct end`
- **THEN** a line says there is no run and nothing changes

### Requirement: Validated settings keys
Public keys SHALL be `card.scale` (50-200), `card.background-opacity` (0-100), `card.text-opacity` (0-100) and `card.locked` (on|off). The UI and the commands SHALL share validators. Unknown keys, bad values, missing arguments and surplus input SHALL be rejected without writes.

#### Scenario: Bad value
- **WHEN** the player runs `/ct set card.scale 500`
- **THEN** nothing is written and the valid range is shown

#### Scenario: Good value
- **WHEN** the player runs `/ct set card.text-opacity 80`
- **THEN** the setting is saved, the card updates, and one line confirms it

### Requirement: Log clear needs confirmation
`/ct log clear` SHALL clear only the diagnostic log after confirmation and SHALL keep plans, runs and settings.

#### Scenario: Clear
- **WHEN** the player confirms `log clear`
- **THEN** the log is empty and runs are unchanged

### Requirement: CheckThat has a short and a long command
The addon SHALL register `/ct` and `/checkthat` with the same vocabulary and SHALL NOT register any other chat command.

#### Scenario: Short form
- **WHEN** the player runs `/ct help`
- **THEN** the help text is shown

#### Scenario: Long form
- **WHEN** the player runs `/checkthat status`
- **THEN** the same status is shown as for `/ct status`
