# Spec Delta

## ADDED Requirements

### Requirement: The macrorun marker command
`/ct macrorun <step id>` SHALL take exactly one argument. It SHALL compare the id with the current step and only log or print, never record a result. A match SHALL log `macro run <id>` and print nothing. A mismatch SHALL print one chat line and log `macro stale <id> card <current id>`, with `none` when no step is open.

#### Scenario: Matching step
- **WHEN** the current step is `a.1` and the player types `/ct macrorun a.1`
- **THEN** the debug log has `macro run a.1` and chat prints nothing

#### Scenario: Another step
- **WHEN** the current step is `a.2` and the player types `/ct macrorun a.1`
- **THEN** chat says the macro is for step a.1 and the card shows step a.2, and the debug log has `macro stale a.1 card a.2`

#### Scenario: No step open
- **WHEN** no run is open and the player types `/ct macrorun a.1`
- **THEN** the debug log has `macro stale a.1 card none`

#### Scenario: Missing argument
- **WHEN** the player types `/ct macrorun`
- **THEN** chat prints the usage line and nothing is logged
