# Spec Delta

## MODIFIED Requirements

### Requirement: Action assistance stays player-driven
The runner MAY show copy boxes for allowed commands, a button whose click is the player's hardware event, a macro created or updated out of combat, and a Reload button. It SHALL NOT send input, target, cast, loot, buy, sell, run unattended, or configure a secure button in combat; a deferred change SHALL apply when combat ends. The secure button SHALL be a separate top-level frame so the checklist card stays movable, resizable and hideable in combat.

#### Scenario: Secure button
- **WHEN** a step offers a macro
- **THEN** it runs only when the player clicks

#### Scenario: Combat
- **WHEN** the player is in combat as a step changes
- **THEN** the secure button is hidden for the whole of combat, is never built or changed in combat, and is set up again for the current step when combat ends

#### Scenario: Card in combat
- **WHEN** the player drags or collapses the card in combat
- **THEN** no protected-action block occurs

#### Scenario: Existing macro
- **WHEN** the player already has a macro named CT that the runner did not create
- **THEN** the runner leaves it alone and creates the macro under an unused name

#### Scenario: Too many commands
- **WHEN** a step lists more commands than the card has copy boxes
- **THEN** the card offers no Run button, so no command runs unseen

#### Scenario: Note stays with its step
- **WHEN** the player types a note and moves to another step
- **THEN** the note box is empty on the other step

#### Scenario: Manual step with commands
- **WHEN** a manual step lists commands and every command is on the allow list
- **THEN** the card offers the Run button, which runs the commands in order when the player clicks

#### Scenario: Copy boxes
- **WHEN** a step offers a multi-line macro
- **THEN** each command shows in its own read-only box, and typing, cutting or deleting reverts

#### Scenario: After reload
- **WHEN** the player returns from a reload mid-step
- **THEN** the card asks them to check the result, not to reload again
