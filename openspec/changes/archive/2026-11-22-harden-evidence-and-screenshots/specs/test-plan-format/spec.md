## ADDED Requirements

### Requirement: Steps may request a screenshot
A step MAY set `screenshot: true`. It SHALL be a boolean; any other value fails validation.

#### Scenario: Flag accepted
- **WHEN** a step sets `screenshot: true`
- **THEN** the plan validates and the card asks for Print Screen
