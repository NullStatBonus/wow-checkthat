## ADDED Requirements

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
