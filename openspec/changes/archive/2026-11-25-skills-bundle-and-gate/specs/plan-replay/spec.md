# Spec Delta

## ADDED Requirements

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
