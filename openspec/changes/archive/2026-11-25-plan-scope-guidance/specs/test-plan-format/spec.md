## ADDED Requirements

### Requirement: Validation warns about a long plan
`ct.py validate` SHALL warn, without failing, when a plan has more than 25 steps or a section has more than 10 steps, counting each case of a step with `cases` as a step. The warning SHALL name the section or the step count and suggest splitting the plan.

#### Scenario: Plan over 25 steps
- **WHEN** a plan has 26 steps
- **THEN** validation prints a warning that names 26 steps and plan sets, and exits zero

#### Scenario: At the limit
- **WHEN** a plan has 25 steps in sections of at most 10
- **THEN** validation prints no size warning

#### Scenario: Section over 10 steps
- **WHEN** a section has 11 steps
- **THEN** validation prints a warning that names the section

#### Scenario: Cases count
- **WHEN** a section has 9 steps and one of them has 2 cases
- **THEN** it counts as 10 steps and gets no warning
