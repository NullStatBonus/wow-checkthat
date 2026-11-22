## ADDED Requirements

### Requirement: One step at a time, never in the way
The runner SHALL show a movable, collapsible card with the current step's setup, action, exact expected result, what happens next, progress, and fixed-position Pass, Fail, Skip and Undo controls. The attempt and evidence capture SHALL arm when the step appears, before the player acts. The card SHALL remember its position and current step across reload.

#### Scenario: Position kept
- **WHEN** the player reloads
- **THEN** the card keeps its position and current step

### Requirement: Prerequisites surfaced
The runner SHALL show unmet requirements of the current step as blocked and SHALL mark steps for the other client as inapplicable, excluded from progress.

#### Scenario: Wrong client
- **WHEN** a step lists only `forever-camelot` and the client is Classic Era
- **THEN** it is inapplicable and never offered

### Requirement: Action assistance stays player-driven
The runner MAY show copy boxes for allowed commands, a button whose click is the player's hardware event, a macro created or updated out of combat, and a Reload button. It SHALL NOT send input, target, cast, loot, buy, sell, run unattended, or configure a secure button in combat; a deferred change SHALL apply when combat ends.

#### Scenario: Secure button
- **WHEN** a step offers a macro
- **THEN** it runs only when the player clicks

#### Scenario: Combat
- **WHEN** the player is in combat as a step changes
- **THEN** the secure button keeps its old text until combat ends

### Requirement: Auto-verification is read-only
Log assertions and state probes SHALL only read. Unverified results SHALL tell the player to retry or skip.

#### Scenario: Log matched
- **WHEN** the expected debug line appears after the action
- **THEN** the step records evidence matched when the player passes it
