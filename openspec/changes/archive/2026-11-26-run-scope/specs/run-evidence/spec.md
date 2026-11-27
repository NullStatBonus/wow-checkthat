## ADDED Requirements

### Requirement: A run-scoped check reads the lines since the run started
When a run starts, the runner SHALL save the position of each log source that a `run`-scoped assertion of the plan names, in the same shape as an attempt's positions. A `run`-scoped assertion SHALL read the lines after that position, across `/reload`, with the same rules for an inexact boundary and a rolled log as an attempt-scoped one. A run without a saved position for the source SHALL leave the assertion unverified. Adding the positions SHALL raise `Run.FORMAT_REV`.

#### Scenario: Error in an earlier step
- **WHEN** a Lua error happens during step 3 and the last step checks with `scope: run` that no error was recorded
- **THEN** the last step fails and names the error

#### Scenario: Error from an earlier run
- **WHEN** the saved error list holds an error from a run that ended yesterday and the new run raises none
- **THEN** the `run`-scoped check passes

#### Scenario: Reload during the run
- **WHEN** the player reloads between step 2 and the last step
- **THEN** the `run`-scoped check still reads from the position saved when the run started

#### Scenario: Run saved before the change
- **WHEN** a run without start positions reaches a `run`-scoped check
- **THEN** the check is unverified with the reason that the run has no start position

### Requirement: Run positions and run-scoped detail stay readable by older tools
A run-scoped check that does not pass SHALL save `since: "run"` and no `scope`, because `scope` is a closed list older readers check. The run's positions SHALL stay in the saved variables only: the export and a finished run leave them out.

#### Scenario: Failed run-scoped check
- **WHEN** a run-scoped absence check fails
- **THEN** its outcome holds `since: "run"` and no `scope`

#### Scenario: Export
- **WHEN** the player exports an open run with start positions
- **THEN** the results string holds no `snapshots` on the run
