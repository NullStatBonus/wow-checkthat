## ADDED Requirements

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
