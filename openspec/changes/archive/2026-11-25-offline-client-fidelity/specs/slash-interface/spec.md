# Spec Delta

## MODIFIED Requirements

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
