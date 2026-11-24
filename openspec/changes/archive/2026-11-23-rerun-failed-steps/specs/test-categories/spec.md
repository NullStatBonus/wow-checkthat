## ADDED Requirements

### Requirement: Failed steps can be rerun across categories
`/ct rerun failed` and a row menu item in the Categories window SHALL ask first, then reopen every picked step whose result is fail or unverified, in every category, as pending, keeping earlier attempts. Steps with other results SHALL stay. With no such step a line SHALL say so and no question SHALL show. The question and the reopen message SHALL use the singular for one step.

#### Scenario: Rerun failed
- **WHEN** two steps in two categories failed and the tester accepts `/ct rerun failed`
- **THEN** both steps are pending, every step that passed keeps its result, and the earlier attempts stay in the export

#### Scenario: Nothing failed
- **WHEN** no step failed or is unverified
- **THEN** a line says so and no question shows

#### Scenario: One step
- **WHEN** a rerun reopens one step
- **THEN** the question says "1 completed step" and the message says "Reopened 1 step"
