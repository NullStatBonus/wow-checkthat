# slash-interface Specification

## Purpose
The /ct command vocabulary and the validated settings keys.

## Requirements

### Requirement: Common command vocabulary
`/ct` SHALL open the checklist. `settings [page]`, `help [topic]`, `status [topic]`, `get <key>`, `set <key> <value>`, `debug on|off`, `log`, `log clear` and `census` SHALL behave as in the sibling addons or, for `census`, as the client-census capability says. Runner commands SHALL be `import`, `start <addon>`, `end`, `pass|fail|skip [note]`, `undo`, `export`, `macro` and `reload`. `end` SHALL use the same confirmation and code path as End run on the card. `/ct help diagnostics` SHALL list `census`.

#### Scenario: Help topics
- **WHEN** the player runs `/ct help diagnostics`
- **THEN** the debug, log and census commands are listed

#### Scenario: End with confirmation
- **WHEN** a run is active and the player runs `/ct end` and confirms
- **THEN** the run ends exactly as from the card menu

#### Scenario: End with no run
- **WHEN** no run is active and the player runs `/ct end`
- **THEN** a line says there is no run and nothing changes

#### Scenario: Census takes no arguments
- **WHEN** the player runs `/ct census now`
- **THEN** a usage line says the command takes no arguments and no census starts

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

### Requirement: Category commands
`/ct categories` SHALL list each category with its title, its id, its state word and counts, and an overall line. `/ct run <category or step id>` SHALL add and show a category or show a step. `/ct rerun <category>` SHALL ask, then reopen a category. Each SHALL reject surplus input and unknown names with a usage line and change nothing. `/ct help runs` and the About page SHALL list them.

#### Scenario: List
- **WHEN** the tester types `/ct categories` during a run
- **THEN** one line per category shows "Bank (bank): failed, 1 passed, 1 failed, 0 open" and a last line shows the overall result

#### Scenario: No run
- **WHEN** the tester types `/ct run bank` with no run
- **THEN** a line says there is no run

#### Scenario: Surplus input
- **WHEN** the tester types `/ct categories now please`
- **THEN** a usage line shows and nothing changes

#### Scenario: Categories window
- **WHEN** the tester types `/ct tracker`
- **THEN** the Categories window opens, or closes if it was open, and `/ct tracker now` is refused with a usage line

#### Scenario: Self-test commands
- **WHEN** the tester types `/ct selftest facts` or `/ct selftest error` during a run
- **THEN** the test facts are reported, or a test error is passed to the error handler

### Requirement: Rerun takes failed
`/ct rerun failed` SHALL ask, then reopen the failed and unverified steps of the run. Its usage line SHALL read `/ct rerun <category> or /ct rerun failed`.

#### Scenario: Usage
- **WHEN** the tester types `/ct rerun` with no name
- **THEN** the usage line names both a category and failed

### Requirement: The macrorun marker command
`/ct macrorun <step id>` SHALL take exactly one argument. It SHALL compare the id with the current step and only log or print, never record a result. A match SHALL log `macro run <id>` and print nothing. A mismatch SHALL print one chat line and log `macro stale <id> card <current id>`, with `none` when no step is open.

#### Scenario: Matching step
- **WHEN** the current step is `a.1` and the player types `/ct macrorun a.1`
- **THEN** the debug log has `macro run a.1` and chat prints nothing

#### Scenario: Another step
- **WHEN** the current step is `a.2` and the player types `/ct macrorun a.1`
- **THEN** chat says the macro is for step a.1 and the card shows step a.2, and the debug log has `macro stale a.1 card a.2`

#### Scenario: No step open
- **WHEN** no run is open and the player types `/ct macrorun a.1`
- **THEN** the debug log has `macro stale a.1 card none`

#### Scenario: Missing argument
- **WHEN** the player types `/ct macrorun`
- **THEN** chat prints the usage line and nothing is logged

### Requirement: Chat lines escape plan text, and /ct start is case-insensitive
`/ct categories` SHALL double each `|` in a category title before it prints the line to chat. Other callers of the category line, such as tooltips, SHALL keep the raw text. `/ct start <addon>` SHALL accept the addon of any imported plan, and an addon that `Plan.SLASH` lists, in any letter case. The line for `/ct pass`, `partial`, `fail` and `skip` SHALL take each result and evidence word through `L[]`.

#### Scenario: A bar in a title
- **WHEN** a category title holds `|cffff0000` and the player types `/ct categories`
- **THEN** chat shows `||cffff0000` in that title

#### Scenario: Lower-case addon name
- **WHEN** the player types `/ct start keepthat` with a KeepThat plan imported
- **THEN** a run for KeepThat starts and no usage line shows

#### Scenario: An addon outside the known list
- **WHEN** the player types `/ct start myaddon` with a MyAddon plan imported
- **THEN** a run for MyAddon starts

#### Scenario: Translated result words
- **WHEN** a locale translates "pass" and "matched"
- **THEN** the result line shows the translated words
