## MODIFIED Requirements

### Requirement: Actions are a closed set of kinds
`action.kind` SHALL be one of `manual`, `copy-slash`, `secure-macro`, `reload`, `wait-event`. An action MAY list `commands` offered as copy text. Every slash command, copy text and macro body SHALL be limited to the commands of the plan's addon plus `/reload` and `/console scriptErrors 0|1`. The commands of an addon are the runner-shipped list for an addon the runner knows, the prefixes the addon declared through `CheckThat.Commands`, and the prefixes in the plan's `commands`. A plan SHALL NOT add `/run`, `/script`, `/dump`, `/console`, the game's debug commands, or a command of another addon the runner knows. No kind SHALL cause game input without a user keypress or click. A `wait-event` action SHALL be valid only on an auto step.

#### Scenario: Unknown action kind
- **WHEN** a step uses `kind: cast`
- **THEN** validation fails

#### Scenario: Plan tries to allow its own commands
- **WHEN** a plan macro contains `/run`, `/script`, `/cast`, or another addon's slash command, or the plan lists `/run` or another known addon's command in `commands`
- **THEN** validation fails, in the compiler and on import

#### Scenario: Wait-event without auto
- **WHEN** a step uses `kind: wait-event` and is not an auto step
- **THEN** validation fails

## ADDED Requirements

### Requirement: A plan may be for any addon
A plan's `addon` SHALL be any addon folder name of 1 to 64 letters, digits, `_`, `-`, `.` or `!`. A plan MAY hold `commands`, a list of 1 to 8 slash command prefixes, each one word after a slash. `commands` is plan revision 2.

#### Scenario: Unknown addon with its own prefix
- **WHEN** a plan for `MyAddon` lists `commands: [/my]` and a macro `/my debug on`
- **THEN** validation passes and compile writes `needs: 2`

#### Scenario: Unlisted prefix
- **WHEN** a plan for `MyAddon` without `commands` has a step command `/my debug on`
- **THEN** `ct.py validate` fails and says to list the prefix in `commands`

### Requirement: The runner offers a plan's commands only when the addon under test owns them
Before a Run button or the CT macro offers a command from the plan's `commands`, the runner SHALL check that the addon under test registered it (the game names the addon that wrote the `SLASH_` global). A command registered by another addon or by the game, or not registered, SHALL NOT be offered. Commands the addon declared through `CheckThat.Commands` SHALL be offered without that check. The start screen SHALL list the commands the plan may offer and those it does not.

#### Scenario: Registered by the addon under test
- **WHEN** the plan lists `/my` and `SLASH_MYADDON1 = "/my"` was written by MyAddon
- **THEN** a step with `/my debug on` gets a Run button

#### Scenario: Registered by another addon
- **WHEN** the plan lists `/oth` and another addon wrote the global
- **THEN** no Run button offers `/oth`, and the start screen names it as not offered
