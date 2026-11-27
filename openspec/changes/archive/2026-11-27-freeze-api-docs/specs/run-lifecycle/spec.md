## ADDED Requirements

### Requirement: Pruned runs are named in chat
When starting a run deletes runs beyond Runs to keep, CheckThat SHALL say in chat which runs it deleted, whether or not they were exported.

#### Scenario: Over the limit
- **WHEN** a sixth run starts with Runs to keep at 5
- **THEN** chat says "Deleted the oldest run (<plan>) to keep 5."
