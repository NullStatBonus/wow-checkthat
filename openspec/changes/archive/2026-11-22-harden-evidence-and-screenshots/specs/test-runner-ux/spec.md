## MODIFIED Requirements

### Requirement: Action assistance stays player-driven
The runner MAY show copy boxes for allowed commands, a button whose click is the player's hardware event, a macro created or updated out of combat, and a Reload button. It SHALL NOT send input, target, cast, loot, buy, sell, run unattended, or configure a secure button in combat; a deferred change SHALL apply when combat ends. The secure button SHALL be a separate top-level frame so the checklist card stays movable, resizable and hideable in combat.

#### Scenario: Secure button
- **WHEN** a step offers a macro
- **THEN** it runs only when the player clicks

#### Scenario: Combat
- **WHEN** the player is in combat as a step changes
- **THEN** the secure button keeps its old text until combat ends

#### Scenario: Card in combat
- **WHEN** the player drags or collapses the card in combat
- **THEN** no protected-action block occurs

#### Scenario: Existing macro
- **WHEN** the player already has a macro named WTT that the runner did not create
- **THEN** the runner leaves it alone and creates the macro under an unused name

#### Scenario: Copy boxes
- **WHEN** a step offers a multi-line macro
- **THEN** each command shows in its own read-only box, and typing, cutting or deleting reverts

#### Scenario: After reload
- **WHEN** the player returns from a reload mid-step
- **THEN** the card asks them to check the result, not to reload again
