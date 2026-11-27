## ADDED Requirements

### Requirement: An addon may declare its slash commands
`CheckThat.Commands(addon, list)` SHALL store 1 to 8 slash command prefixes for the addon and return true, and SHALL return false without raising for any other input, for a denied command, or for another known addon's command. `CheckThat.API_VERSION` SHALL be 4.

#### Scenario: Declared commands
- **WHEN** MyAddon calls `CheckThat.Commands("MyAddon", { "/my" })`
- **THEN** it returns true, and a plan for MyAddon that uses `/my` imports and offers it

#### Scenario: Denied command
- **WHEN** an addon calls `CheckThat.Commands("MyAddon", { "/run" })`
- **THEN** it returns false and stores nothing
