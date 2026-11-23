## MODIFIED Requirements

### Requirement: An absence is not shown after the log rolled
When the boundary of an attempt was found by search and the saved tail is not distinctive (fewer than half of its lines differ), a check that a line is absent SHALL be unverified when the new lines hold no such line, and SHALL fail when one does. When the tail is distinctive, the boundary SHALL count as exact and an absence check SHALL be judged on the new lines. Checks for a present line SHALL be judged as before.

#### Scenario: Rolled log
- **WHEN** a ring log rolled over so far that lines near the boundary may be missing
- **THEN** an absence check does not pass

#### Scenario: Flooded tail
- **WHEN** a ring log rolled and the saved tail is one repeated line
- **THEN** an absence check does not pass

#### Scenario: Full ring with a distinctive tail
- **WHEN** a full ring log pushed old lines out and the saved tail is found once
- **THEN** an absence check passes when no new line matches, and fails when one does
