# Spec Delta

## MODIFIED Requirements

### Requirement: Game calls go through the adapter
Every game API read and action SHALL be in `Core/Adapter.lua`, guarded, returning nil when missing. Model code SHALL use no game globals. Frame construction, anchoring and styling in `UI/` and `Debug/` MAY call the game directly. Other modules SHALL NOT.

#### Scenario: Missing API
- **WHEN** a game function does not exist
- **THEN** the adapter returns nil and no Lua error is raised

#### Scenario: UI builds its own frames
- **WHEN** a file in `UI/` or `Debug/` calls `CreateFrame` or reads `UIParent`
- **THEN** the layering test passes

#### Scenario: Game global outside the allowed places
- **WHEN** a file in `Model/`, `Options/` or `Core/` other than the adapter uses a game global
- **THEN** the layering test fails and names the file
