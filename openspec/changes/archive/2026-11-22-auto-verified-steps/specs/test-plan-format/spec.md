# Spec Delta

## MODIFIED Requirements

### Requirement: Actions are a closed set of kinds
`action.kind` SHALL be one of `manual`, `copy-slash`, `secure-macro`, `reload`, `wait-event`. An action MAY list `commands` offered as copy text. Every slash command, copy text and macro body SHALL be limited to the runner-shipped allow list for the plan's addon plus `/reload` and `/console scriptErrors 0|1`. A plan SHALL NOT extend that list. No kind SHALL cause game input without a user keypress or click. A `wait-event` action SHALL be valid only on an auto step.

#### Scenario: Unknown action kind
- **WHEN** a step uses `kind: cast`
- **THEN** validation fails

#### Scenario: Plan tries to allow its own commands
- **WHEN** a plan macro contains `/run`, `/script`, `/cast`, or another addon's slash command
- **THEN** validation fails, in the compiler and on import

#### Scenario: Wait-event without auto
- **WHEN** a step uses `kind: wait-event` and is not an auto step
- **THEN** validation fails

## ADDED Requirements

### Requirement: A step may be settled by its own evidence
A step MAY set `auto: true`. An auto step SHALL list `assertions` in `verify`, SHALL NOT list `player` in `verify`, SHALL have at least one required assertion, and SHALL have no required absence assertion. Validation SHALL reject an auto step that breaks any of these rules, in the compiler and on import.

#### Scenario: Auto step with a required line
- **WHEN** a step sets `auto: true`, verifies by assertions only, and has a required log assertion
- **THEN** validation passes

#### Scenario: Auto step that needs the player
- **WHEN** a step sets `auto: true` and lists `player` in `verify`
- **THEN** validation fails

#### Scenario: Auto step with only diagnostic assertions
- **WHEN** a step sets `auto: true` and every assertion is diagnostic
- **THEN** validation fails

#### Scenario: Auto step with an absence check
- **WHEN** a step sets `auto: true` and a required assertion checks that a line is absent
- **THEN** validation fails

### Requirement: An auto step may set a timeout
An auto step MAY set `timeout`, a whole number of seconds from 5 to 300. A step that is not auto SHALL NOT set `timeout`. A plan SHALL NOT supply a default timeout; a step without one waits for the player.

#### Scenario: Timeout in range
- **WHEN** an auto step sets `timeout: 30`
- **THEN** validation passes

#### Scenario: Timeout out of range
- **WHEN** an auto step sets `timeout: 3` or `timeout: 600`
- **THEN** validation fails

#### Scenario: Timeout without auto
- **WHEN** a step sets `timeout` and does not set `auto: true`
- **THEN** validation fails
