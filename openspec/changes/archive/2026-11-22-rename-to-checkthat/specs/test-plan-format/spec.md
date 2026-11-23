# Spec Delta

## ADDED Requirements

### Requirement: The runner's own plans name CheckThat
A plan for the runner itself SHALL name the addon `CheckThat` and SHALL allow the slash commands `/ct` and `/checkthat` and no others.

#### Scenario: Runner plan
- **WHEN** a plan for `CheckThat` has a macro `/ct status` or `/checkthat status`
- **THEN** validation passes

#### Scenario: Another addon's command
- **WHEN** a plan for `CheckThat` has a macro `/kt debug on`
- **THEN** validation fails
