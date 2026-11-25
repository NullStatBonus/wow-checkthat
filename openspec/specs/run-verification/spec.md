# run-verification Specification

## Purpose
TBD - created by archiving change plan-skill-per-character-and-verify. Update Purpose after archive.

## Requirements

### Requirement: Verify skill reads full results first
The `ct-verify` skill SHALL read saved run data collected with `tools/ct.py collect`, or an `/ct export` string read with `import-results`, as the full result of a run. It SHALL treat a pasted `/ct log` report as partial evidence and SHALL name the steps it cannot judge from it. It SHALL cite run ID, revision, step, attempt and assertion index.

#### Scenario: Pasted report only
- **WHEN** the author gives only a pasted `/ct log` report
- **THEN** the skill reports the steps it can judge and lists the steps it cannot

### Requirement: Verify skill reports verdict and evidence separately
For each step the skill SHALL report the effective verdict, the claimed verdict, who set it and the recorded evidence apart. It SHALL mark a step contradicted only when a hand pass or partial meets a required assertion that recorded fail. A diagnostic assertion SHALL NOT contradict. A hand pass with a required log line missing SHALL read unverified. It SHALL quote a log line only when the data holds it.

#### Scenario: Hand pass, forbidden line present
- **WHEN** a player passed a step whose forbidden line appeared
- **THEN** the report marks the step contradicted and cites the line

#### Scenario: Hand pass, line missing
- **WHEN** a player passed a step whose required log line is absent
- **THEN** the report marks the step unverified

### Requirement: Verify skill binds runs to their plans
The skill SHALL obtain each role's plan from its compiled plan file or from the copied plan store and SHALL check the run's plan digest against it. If it cannot establish the exact plan it SHALL say so before it reads any assertion or reviewer text. It SHALL resolve each reviewer reference as a role file and a step ID, and SHALL use the latest revision of each run ID.

#### Scenario: Exact plan unknown
- **WHEN** a run was exported and its plan copy is not available
- **THEN** the skill says it cannot establish the plan and does not read assertion indices

### Requirement: Verify skill pairs partner runs
The skill SHALL require the partner runs to come from distinct characters. When more than one eligible assignment of runs to roles remains it SHALL list them and ask the author for run IDs. A unique assignment SHALL proceed without a question. A role with no collected run SHALL read unverified, never pass. It SHALL support any number of roles.

#### Scenario: Two runs for one role
- **WHEN** two runs of the same plan exist for one role
- **THEN** the skill lists both and asks which to use

#### Scenario: Unique assignment
- **WHEN** each role has exactly one eligible run
- **THEN** the skill pairs them without asking

#### Scenario: Partner run missing
- **WHEN** one role's run is collected and the other's is not
- **THEN** the cross-character check reads unverified and names the missing role

### Requirement: Verify skill only reports
The skill SHALL NOT edit a plan, SHALL NOT run the game and SHALL NOT put raw saved variables in Git. It SHALL write collected evidence outside the installed skill.

#### Scenario: Plan needs a new assertion
- **WHEN** the report suggests an assertion
- **THEN** the skill leaves the plan unchanged

### Requirement: Installed bundle can decode saved variables
The installed bundle SHALL hold every file that `collect` needs, and `collect` SHALL report a decode failure when it extracts no runs from a file that held a run.

#### Scenario: Collect from a sibling directory
- **WHEN** `collect` runs from a sibling directory on a saved variables file with one run
- **THEN** it extracts that run's revision and steps

### Requirement: Runs and reports carry categories
A run SHALL record its categories in plan order, the category of each step and the picked set. A run saved without them SHALL read as every category picked. The report SHALL show a line per category with its state and counts, and SHALL list deselected steps apart from skipped and unverified ones. The results string SHALL stay version 1.

#### Scenario: Report rollup
- **WHEN** a run has one failed category and one green category
- **THEN** the report shows the first as red with its failed steps and the second as green

#### Scenario: Old run
- **WHEN** a run saved before categories is opened
- **THEN** it reads as one pick of every section, with no errors

#### Scenario: Deselected is not unverified
- **WHEN** a category was not picked
- **THEN** its steps appear as deselected and do not count toward unverified evidence

### Requirement: Diff two finished runs
`ct.py diff <A> <B>` SHALL judge both runs as `report` does and label each step `regressed`, `fixed`, `newly-unverified`, `still-failing`, `not-comparable`, `added` or `removed`. Its header SHALL show client, build, character, plan digest and writer version of each run, and "plan changed" when the digests differ. A step that is pending, skipped, deselected, not for the client or reopened on either side SHALL be `not-comparable`. `--strict` SHALL exit 1 when a step regressed, and the command SHALL exit 2 for an unknown run, a run left out or an unfinished run (without `--include-open`).

#### Scenario: Pass to fail
- **WHEN** a step passed in A and failed in B
- **THEN** it is `regressed`, and `--strict` exits 1

#### Scenario: Contradicted pass
- **WHEN** B records pass but a required check failed
- **THEN** B counts the step as fail

#### Scenario: Plan edited
- **WHEN** the plan digests differ
- **THEN** the header says "plan changed" and steps only one run has are `added` or `removed`

#### Scenario: Unknown run
- **WHEN** a run name matches no run
- **THEN** the command exits 2

### Requirement: Never guess across a plan edit
When two runs have different plan digests, a step SHALL be compared only when both stored plans name it and its fingerprints match. A changed step, or a plan missing from the collected saved variables, SHALL give `not-comparable`. A missing plan SHALL print a warning.

#### Scenario: Step edited
- **WHEN** the step differs in the two stored plans
- **THEN** it is `not-comparable`

#### Scenario: Plan not collected
- **WHEN** a digest has no stored plan
- **THEN** a warning names the digest and no step is guessed comparable

### Requirement: Trend over many runs
`ct.py trend` SHALL print, for each addon and plan title, one row for each step and one column for each finished run, oldest first, and SHALL mark a step flaky when comparable runs both passed and failed or went unverified. `--addon`, `--title`, `--by`, `--last` and `--include-open` SHALL narrow or extend the runs. A run in a newer format SHALL be left out and listed in a warning.

#### Scenario: Flaky step
- **WHEN** a step passed, failed and passed in three runs
- **THEN** it is marked flaky

#### Scenario: Open run
- **WHEN** a run has not ended
- **THEN** it is left out unless `--include-open` is given
