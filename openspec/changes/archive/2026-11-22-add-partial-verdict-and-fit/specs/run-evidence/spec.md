## ADDED Requirements

### Requirement: Partial verdict
A step MAY be recorded as partial, meaning it mostly works. A partial claim SHALL be gated by required evidence exactly like a pass: matched evidence records partial, contradicting evidence records fail, missing evidence records unverified. A partial step SHALL advance the run like a pass, SHALL be counted separately, and SHALL be listed in the report with its note.

#### Scenario: Partial with evidence
- **WHEN** the player records partial with a note and the required evidence matched
- **THEN** the attempt records partial with the note and the run moves to the next step

#### Scenario: Partial without evidence
- **WHEN** the player records partial and required evidence is missing
- **THEN** the attempt records unverified and the step stays open
