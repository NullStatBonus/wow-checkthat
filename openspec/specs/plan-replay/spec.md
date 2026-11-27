# plan-replay Specification

## Purpose
Judge a plan's checks offline against a saved-variables fixture, so a plan edit or a log text change fails a build before a tester runs the plan.

## Requirements

### Requirement: Replay judges checks against a fixture
`ct.py replay <plan> --sv <dir>` SHALL judge each step's log and fact assertions against the decoded saved variables in the fixture, using the whole log as the window. It SHALL print JUnit and exit non-zero when a required check is contradicted.

#### Scenario: Typo in a log check
- **WHEN** a plan's `contains` text matches no line in the fixture
- **THEN** the step fails and the exit code is non-zero

#### Scenario: Corrected plan
- **WHEN** the typo is fixed
- **THEN** the step passes and the exit code is zero

#### Scenario: Forbidden line present
- **WHEN** a required `absent` check names a line the fixture holds
- **THEN** the step fails

### Requirement: Checks that need a window never pass offline
A check that needs a step window (`exactly`, `max`, `absent` on an attempt scope) or a state probe the fixture lacks SHALL report "not judged offline". It SHALL NOT count as a pass.

#### Scenario: State probe without data
- **WHEN** a step needs a state value the fixture does not hold
- **THEN** the report marks it not judged offline and the build does not count it as passed

### Requirement: Report names the fixture's age
The report SHALL print the fixture's age and the plan digest it was recorded with, and SHALL warn when the digest differs from the plan being replayed.

#### Scenario: Stale fixture
- **WHEN** the fixture was recorded for another plan digest
- **THEN** the report prints a stale-fixture warning

### Requirement: Flow replay works for any addon's plan
`ct.py replay-flow <plan>` SHALL play every step of the plan in the fake client and exit non-zero on a problem. For a log source that is not CheckThat's own, it SHALL write the lines the step's checks look for into that source, derived from literal lines, patterns and sequences. It SHALL print that the evidence is assumed, and SHALL report a check it cannot derive instead of guessing.

#### Scenario: Plan for another addon replays without hooks
- **WHEN** a plan for another addon asserts log patterns in that addon's saved variable
- **THEN** the replay settles each automatic step and prints "evidence assumed"

#### Scenario: Pattern with no sample
- **WHEN** a check's pattern has a back-reference
- **THEN** the replay warns "evidence not derived" and the step does not settle

### Requirement: Bundle runs replay and offline without a checkout
The installed skill SHALL run `validate`, `compile`, `replay-flow` and `offline` from a folder that has no CheckThat checkout beside it.

#### Scenario: Run from another folder
- **WHEN** the skill is installed and `replay-flow` and `offline` run with another folder as the working folder
- **THEN** both succeed and write nothing to that folder

### Requirement: Asserted lines are checked against the addon source
`ct.py lines <plan> --addon-src <folder>` SHALL list each asserted log line and fact key that no Lua file of the addon contains, and exit non-zero only with `--strict`.

#### Scenario: Line missing from the source
- **WHEN** a plan asserts a line the addon source lacks
- **THEN** the command names the step and the line

### Requirement: Lines built from format strings are found
`ct.py lines` SHALL count an asserted line as found when it is part of the text a format string in the addon source can produce, with each placeholder (`%s`, `%d` and the other `string.format` conversions) read as any text and `%%` as a percent sign. At least 8 characters of the asserted line, and at least half of them, SHALL come from the format string's own literal text, so a string made mostly of placeholders, or one placeholder that takes the rest of the line, does not match everything.

#### Scenario: Asserted text spans placeholders
- **WHEN** the source has `("trigger %s%s%s (bags=%s free)"):format(...)` and the plan asserts `trigger go sell (bags=`
- **THEN** `ct lines` reports the line as found

#### Scenario: One placeholder takes the rest
- **WHEN** the source has `("trigger %s (boxes=%s"):format(...)` and the plan asserts `trigger go sell (bags=`
- **THEN** `ct lines` reports it as not found, because only 8 of its 22 characters come from the format string

#### Scenario: Placeholders alone
- **WHEN** the source has `("%s %s"):format(a, b)` and the plan asserts a line no other source text contains
- **THEN** `ct lines` still reports it as not found

### Requirement: Replay judges a plan against a collected run
`ct.py replay <plan> --run <run id>` SHALL judge the plan's log and fact checks against the saved variables collected with that run's newest stored revision, by the same rules as `--sv`. Exactly one of `--sv` and `--run` SHALL be given; `--dest` names the evidence folder and defaults to `evidence`. The command SHALL print each saved-variables copy it used.

#### Scenario: Revised plan against the failing run
- **WHEN** the author runs `ct replay plans/x.yaml --run <id>` after a run was collected
- **THEN** the checks are judged against that run's collected copies and the JUnit result is printed, with no fixture folder made by hand

#### Scenario: Unknown run
- **WHEN** no run with that id is stored under the evidence folder
- **THEN** the command exits 2 and names the run id

### Requirement: Replay picks the copies of the run's own collect
For `--run`, the CheckThat copy SHALL be the newest collected copy of `CheckThat.lua` that holds the run at its newest stored revision. The other copies SHALL come from the same client folder and account as that copy: each account-wide addon file, and each addon file of the run's own character folder, never another character's.
#### Scenario: Two characters share a log global
- **WHEN** the run's character and another character both have a collected `ClosestVendor.lua` with the same per-character global
- **THEN** only the run's character's copy is used

#### Scenario: Several collects
- **WHEN** a character's addon file was collected three times, once before, once with and once after the chosen CheckThat copy
- **THEN** the copy collected with it is used

#### Scenario: Unchanged file
- **WHEN** an account-wide addon file did not change since an earlier collect, so its only copy is older than the CheckThat copy
- **THEN** that older copy is used and no warning is printed

### Requirement: Replay uses one collect's copies
For `--run`, of the copies of one file the newest one collected no later than the CheckThat copy (with one minute of slack) SHALL be used: `collect` stores each content once, so a file that did not change keeps the copy of its first collect. When every copy of a file is later, the earliest SHALL be used and named in a warning. When no CheckThat copy holds the run at its newest stored revision, the command SHALL exit 2 and say to collect again.

#### Scenario: Run not in any copy
- **WHEN** the run's newest stored revision is 5 and no collected `CheckThat.lua` holds revision 5
- **THEN** the command exits 2 and says to collect again

### Requirement: Flow replay covers async and inapplicable steps
`ct replay-flow` and `tests/replay_plan.lua` SHALL settle an async step at run start when its fixture lines exist before the first step, and SHALL report a step with an `unmet: inapplicable` requirement as inapplicable when the hooks file marks the requirement unmet.

#### Scenario: Async version step
- **WHEN** the fixture holds the version fact before the run starts
- **THEN** the replay records the step passed at start and never shows it
