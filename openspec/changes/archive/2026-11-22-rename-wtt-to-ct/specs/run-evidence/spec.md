# Spec Delta

## MODIFIED Requirements

### Requirement: External scripts collect evidence centrally
Provided scripts SHALL copy CT and tested-addon SavedVariables from a WTF or saved-copy directory into one central directory, deduplicating by content hash and by run ID plus revision, convert SavedVariables and results strings to JSON, and write a readable report of every non-passing step. Scripts SHALL NOT modify game files.

#### Scenario: Duplicate collection
- **WHEN** the script runs twice with no new reload
- **THEN** the central directory has one copy per file and one file per run revision
