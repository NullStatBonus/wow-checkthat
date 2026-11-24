## ADDED Requirements

### Requirement: The report shows the newest error stack
The `/ct log` report SHALL show the newest kept error stack on a `Last error stack:` line, and no such line when none is kept.

#### Scenario: A stack is kept
- **WHEN** an error kept a stack
- **THEN** the report holds a `Last error stack:` line with it
