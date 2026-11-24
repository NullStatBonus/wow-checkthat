# Spec Delta

## ADDED Requirements

### Requirement: Runs and reports carry categories
A run SHALL record its categories in plan order, the category of each step and the picked set. A run saved without them SHALL read as every category picked. The report SHALL show a line per category with its state and counts, and SHALL list deselected steps apart from skipped and unverified ones. The results string SHALL stay version 1.

#### Scenario: Report rollup
- **WHEN** a run has one failed category and one green category
- **THEN** the report shows the first as red with its failed steps and the second as green

#### Scenario: Old run
- **WHEN** a run saved before categories is opened
- **THEN** it reads as one pick of every section, with no errors

#### Scenario: Deselected is not unverified
- **WHEN** a category was not picked
- **THEN** its steps appear as deselected and do not count toward unverified evidence
