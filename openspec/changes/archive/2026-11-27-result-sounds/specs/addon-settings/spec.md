## ADDED Requirements

### Requirement: Result sounds setting
Appearance SHALL offer a "Play result sounds" checkbox, on by default. `/ct set card.sound on|off` SHALL change it, and the debug report SHALL show its value. When it is off, CheckThat SHALL play and log no result sound; `/ct sound` previews SHALL still play.

#### Scenario: Sounds off
- **WHEN** the player turns Play result sounds off and a step passes
- **THEN** no sound plays and the log has no `sound` line for that step
