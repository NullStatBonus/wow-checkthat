# Spec Delta

## ADDED Requirements

### Requirement: A command reports a test fact
`/ct fact` SHALL take no arguments and SHALL report the fact `[CheckThat] selftest=1` through the same path as `CheckThat.Report`, with the same run gate and limits. It SHALL print one line that says whether the fact was recorded.

#### Scenario: Run open
- **WHEN** a run is open and the player runs `/ct fact`
- **THEN** the line `[CheckThat] selftest=1` is added to the facts list and a line says the fact was reported

#### Scenario: No run open
- **WHEN** no run is open and the player runs `/ct fact`
- **THEN** nothing is recorded and a line says no run is open

#### Scenario: Arguments
- **WHEN** the player runs `/ct fact` with an argument
- **THEN** a usage line is printed and nothing is recorded

#### Scenario: Self-test step
- **WHEN** the player clicks Run on the self-test step that reports a fact
- **THEN** the step passes by itself with no typing
