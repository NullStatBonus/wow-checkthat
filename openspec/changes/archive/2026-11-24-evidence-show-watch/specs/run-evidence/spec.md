## ADDED Requirements

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
