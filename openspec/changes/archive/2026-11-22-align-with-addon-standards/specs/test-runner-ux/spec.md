## ADDED Requirements

### Requirement: Notes and share points
The card SHALL offer a one-line note box saved with the verdict. After a step with a share point, the card SHALL open the results export or ask for a reload so the log reaches the saved file. Unverified steps SHALL name the missing evidence and offer Retry or Skip with a note.

#### Scenario: Export share point
- **WHEN** the player records a verdict on a step with `share: export`
- **THEN** the results string opens in the copy window

#### Scenario: Note kept
- **WHEN** the player types a note and presses Fail
- **THEN** the note is stored in the attempt and shown in the report
