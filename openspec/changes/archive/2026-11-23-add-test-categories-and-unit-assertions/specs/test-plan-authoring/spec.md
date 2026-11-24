# Spec Delta

## ADDED Requirements

### Requirement: Compilation merges categories
Compilation SHALL write a section's `category` into each of its steps that has none, and SHALL leave the plan's `categories` as declared.

#### Scenario: Merge
- **WHEN** a section sets a category and a step in it sets another
- **THEN** the step keeps its own and the others take the section's

### Requirement: Parameterized steps expand at compile time
A step MAY set `cases`, a list of up to 50 objects with a unique `id` suffix and `vars`. Compilation SHALL replace each `{{name}}` in the step's text and assertions with the case's var, SHALL give each expanded step the id `<id>.<suffix>`, and SHALL remove `cases`. An unknown placeholder or a duplicate suffix SHALL fail compilation. The runner SHALL NOT see `cases`.

#### Scenario: Three cases
- **WHEN** a step with id `bind` has cases `cloth`, `leather` and `mail`
- **THEN** the plan holds the steps `bind.cloth`, `bind.leather` and `bind.mail`

#### Scenario: Unknown placeholder
- **WHEN** step text names `{{slot}}` and a case has no `slot` var
- **THEN** compilation fails and names the step and the case

#### Scenario: Plan with cases imported
- **WHEN** a plan string that still holds `cases` is imported
- **THEN** validation fails
