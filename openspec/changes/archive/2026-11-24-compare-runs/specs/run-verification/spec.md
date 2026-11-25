# Spec Delta

## ADDED Requirements

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
