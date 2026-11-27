## ADDED Requirements

### Requirement: A reload marks the character's open run
After a reload the runner SHALL mark the open attempt of the character's open run as reloaded and SHALL print the resume lines for that run. It SHALL NOT mark or report a run that is only shown on the card, such as an ended run opened from Past runs.

#### Scenario: Past run on the card
- **WHEN** the card shows an ended run while another run has an open attempt, and the player reloads
- **THEN** the open run's attempt is marked as reloaded, chat names the open run, and the ended run is not reported as resumed

#### Scenario: No open run
- **WHEN** the character has no open run after a reload
- **THEN** no resume line is printed and no attempt is marked
