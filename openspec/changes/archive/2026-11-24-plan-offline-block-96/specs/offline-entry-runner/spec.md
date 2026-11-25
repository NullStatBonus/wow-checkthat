# Spec Delta

## ADDED Requirements

### Requirement: Offline command runs a plan's block
`ct.py offline <plan>` SHALL run the plan's offline block in the runner, resolving `toc` from the plan file's folder. It SHALL print JUnit with one case for each step, exit 1 when a step fails, and exit 2 when the plan has no block or the run cannot start.

#### Scenario: Wrong return
- **WHEN** a call step expects a value the entry does not return
- **THEN** that case fails and the exit code is 1

#### Scenario: Matching plan
- **WHEN** every step matches
- **THEN** the exit code is 0

#### Scenario: No block
- **WHEN** the plan has no offline block
- **THEN** the command exits 2 and says so

### Requirement: Only listed APIs can be mocked
The runner SHALL hold a closed list of mockable API names. A mock for a name not on the list SHALL stop the run before the addon loads and fail with the name. A plan cannot add to the list.

#### Scenario: Unlisted mock
- **WHEN** a plan mocks `loadstring`
- **THEN** the run fails before any addon file loads and nothing is replaced
