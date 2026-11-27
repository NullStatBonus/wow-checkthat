## ADDED Requirements

### Requirement: The export window names what identifies the tester
The window that shows a results string SHALL say that the results include the character and realm name. The debug report window SHALL show only the copy hint.

#### Scenario: Export results
- **WHEN** the player exports a run
- **THEN** the line under the string says "The results include your character and realm name." before the copy hint
