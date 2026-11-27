## ADDED Requirements

### Requirement: Skill writes several actions as a list
When a step needs more than one player action or names more than one result, the skill SHALL write `action.text` or `expect` as a list, one sentence per item, two to six items. One action and one result stay strings.

#### Scenario: Three actions
- **WHEN** a step asks the player to walk in, wait and walk out
- **THEN** the draft lists the three actions under `action.text`
