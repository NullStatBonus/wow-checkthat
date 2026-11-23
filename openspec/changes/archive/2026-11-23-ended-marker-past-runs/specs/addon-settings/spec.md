## ADDED Requirements

### Requirement: Past runs mark ended runs
Each Past runs entry for an ended run SHALL end with `, ended` after the counts. An unfinished run SHALL carry no such marker.

#### Scenario: Ended and open rows
- **WHEN** Home lists one ended run and one unfinished run
- **THEN** only the ended run's entry ends with `, ended`
