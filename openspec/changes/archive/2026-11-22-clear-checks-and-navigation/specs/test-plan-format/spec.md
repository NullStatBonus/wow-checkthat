## ADDED Requirements

### Requirement: Assertions may carry a label
An assertion MAY set `label`, a player-readable name for the check, in native formatting. The card shows it in the live checks; without one it shows a generic description.

#### Scenario: Labelled check
- **WHEN** an assertion sets `label: Hooks started`
- **THEN** the card lists "Hooks started" among the live checks
