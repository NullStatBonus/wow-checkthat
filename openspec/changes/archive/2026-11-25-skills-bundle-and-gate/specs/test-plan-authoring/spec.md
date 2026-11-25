# Spec Delta

## ADDED Requirements

### Requirement: Handoff gate before a tester runs a plan
The skill SHALL run `validate`, `compile`, `replay-flow`, `lines` and (when the plan has one) `offline`, then an independent review of the plan against what the card shows, and SHALL fix every finding in the same session. It SHALL say plainly when a step was not run, and which plan version an earlier in-game run used.

#### Scenario: No luajit
- **WHEN** `luajit` is missing
- **THEN** the skill says the plan was not replayed

### Requirement: Step ids stay put
The skill SHALL tell the author never to renumber or rename an existing step id. `ct.py diff` SHALL mark a step that kept its text and changed its id as renamed and warn that its history is split.

#### Scenario: Renamed step
- **WHEN** two runs of different plan versions hold a step with the same text under different ids
- **THEN** `diff` shows "renamed to" and "renamed from" and a warning

### Requirement: Offline question in the interview
The interview SHALL ask which scope items need no client and draft those as offline steps first.

#### Scenario: Pure function in scope
- **WHEN** a scope item is a classification the addon exposes as an entry
- **THEN** the skill drafts an offline step for it before any player step

### Requirement: Optional pull request block
The skill SHALL offer a pull request block with one unticked checkbox for each manual check and plan step, each with its full text.

#### Scenario: Manual check in the block
- **WHEN** the author asks for the block
- **THEN** each manual check appears unticked with its setup, action, Check and Log text, not a pointer

### Requirement: Card-moving commands are warned about
`ct.py validate` SHALL warn about a manual step whose `commands` include a CheckThat command that records a result or moves the card, unless the step's notes say it is on purpose.

#### Scenario: Pass in the Run button
- **WHEN** a manual step lists `/ct pass` in its commands
- **THEN** `validate` names the step and the command
