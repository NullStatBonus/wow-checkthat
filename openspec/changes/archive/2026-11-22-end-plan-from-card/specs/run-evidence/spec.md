## ADDED Requirements

### Requirement: Ended runs stay recorded
Ending a run SHALL set an optional run-level `endedAt` time and bump the revision once. The end SHALL keep every step record, attempt and note. Exports, the saved run and the debug report SHALL mark the run ended, even when every recorded verdict is pass. An ended run SHALL accept no verdict, Undo, auto-settle or reload resume. A saved run without `endedAt` SHALL read as not ended.

#### Scenario: Ended run exported
- **WHEN** a player ends a run with 3 of 8 steps resolved and exports it
- **THEN** the export holds the 3 verdicts, the 5 steps as they were, and the ended time

#### Scenario: Reload after end
- **WHEN** the player reloads after ending a run
- **THEN** the run is still ended and no step resumes
