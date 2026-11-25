# Spec Delta

## ADDED Requirements

### Requirement: A repeated tail gives an inexact boundary
When the saved tail of an attempt appears more than once in a log and not at the saved position, the boundary SHALL be the last match and SHALL NOT be exact. A check that a line is present SHALL be judged on the new lines. An absence or count check SHALL be unverified.

#### Scenario: Repeated run
- **WHEN** a full ring log holds the saved tail twice
- **THEN** the new lines after the last match are used and an absence check does not pass

### Requirement: Undo and stale macro presses leave evidence
Undo SHALL log `undo <step id>: reopened`. A stale macro press SHALL add one to `macroStale` on the step record the card showed, and the report and diff SHALL show the count.

#### Scenario: Undo
- **WHEN** the player undoes a step
- **THEN** the debug log has `undo <step id>: reopened`

#### Scenario: Stale press
- **WHEN** the CT macro runs while the card shows another step
- **THEN** that step record has `macroStale` raised by one
