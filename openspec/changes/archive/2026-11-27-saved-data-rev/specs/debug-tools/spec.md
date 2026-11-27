## ADDED Requirements

### Requirement: The report names the saved-data revision
The debug report SHALL print `Saved data: rev <n>` with the shape revision of the saved global table, and SHALL add that it is newer than this version and left as it is when the revision is above the one this version writes.

#### Scenario: Current revision
- **WHEN** the report is built after a normal load
- **THEN** it holds `Saved data: rev 1`

#### Scenario: Newer revision
- **WHEN** the saved table has a revision above this version's
- **THEN** the report names both revisions and says the data is left as it is
