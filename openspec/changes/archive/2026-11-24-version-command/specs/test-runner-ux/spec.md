# Spec Delta

## ADDED Requirements

### Requirement: The version command
`/ct version` SHALL print the CheckThat version. While a run is open and the version has the form major.minor.patch, it SHALL also report the fact `version` with the value major*10000 + minor*100 + patch. It SHALL take no arguments.

#### Scenario: Version during a run
- **WHEN** a run is open, the version is 0.17.0 and the tester types `/ct version`
- **THEN** chat shows "CheckThat 0.17.0" and the fact `[CheckThat] version=1700` is recorded

#### Scenario: No run
- **WHEN** no run is open and the tester types `/ct version`
- **THEN** chat shows the version and no fact is recorded
