# Spec Delta

## ADDED Requirements

### Requirement: Report warns about the build a run used
`ct.py report` SHALL warn, with `--expect-version` and `--plan`, about a run whose tested addon version differs from the expected one, whose CheckThat writer version differs from the tools' version, or whose plan digest differs from the plan file's. A run with no record of a field SHALL draw no warning for it.

#### Scenario: Plan edited since the run
- **WHEN** the plan file compiles to another digest than the run's
- **THEN** the report warns that edits since the run are untested

### Requirement: Saved variables before more steps
`ct-verify` SHALL collect and read saved variables before it asks the author for more in-game steps.

#### Scenario: Author has not collected yet
- **WHEN** the author asks what to test next and no evidence is collected
- **THEN** the skill collects and reads the saved variables first
