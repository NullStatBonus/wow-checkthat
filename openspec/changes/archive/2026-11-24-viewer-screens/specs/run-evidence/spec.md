## ADDED Requirements

### Requirement: The viewer's runs and steps screens show state in words and marks
The viewer SHALL show each run's and step's state as a word and a mark (color only helps), SHALL count each run once with fail before unverified and call the rest "no flags", and SHALL show steps done over steps that apply. Below 76 columns the screens SHALL show only the result, the id and (for runs) the done fraction; from 76 columns they SHALL add the other columns. A category chip SHALL follow the evidence-based result of its steps. A filter with no match SHALL say so.

#### Scenario: A narrow terminal
- **WHEN** the terminal is 40 columns wide
- **THEN** the runs table has the result, run and done columns, and a resize to 100 columns brings back plan, revision, counts and age

#### Scenario: An overturned pass
- **WHEN** a step's pass is contradicted by its required evidence
- **THEN** its category chip is red, not green
