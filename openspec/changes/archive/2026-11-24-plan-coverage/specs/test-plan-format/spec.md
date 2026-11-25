# Spec Delta

## MODIFIED Requirements

### Requirement: Plans may declare categories
A plan MAY set `categories`: a list of objects with a unique `id` (lower case letters, digits, dot, dash), a `title` and an optional `intro`. A step or section MAY set `category` to a declared id. A plan that declares categories SHALL have every step resolve to one. Unknown ids SHALL fail validation, in the compiler and on import.

#### Scenario: Unknown category id
- **WHEN** a step names a category the plan does not declare
- **THEN** validation fails and names the step and the id

#### Scenario: Section default
- **WHEN** a section sets `category: bank`
- **THEN** every step in it lists `bank` after compilation unless it names its own

## ADDED Requirements

### Requirement: Tools reject unknown fields and the game ignores them
The schema SHALL set `additionalProperties: false`, so `ct.py` rejects an unknown field. `Plan.Validate` in the game SHALL ignore a field it does not know, so a field meant only for the tools never stops an import.

#### Scenario: Tool rejects
- **WHEN** a step has a field the schema does not list
- **THEN** `ct.py validate` fails

#### Scenario: Game ignores
- **WHEN** an imported plan has an unknown field on a step or section
- **THEN** `Plan.Validate` returns no error for it

### Requirement: Steps and sections may name the requirements they cover
A step or section MAY set `covers`: a list of requirement names, each the text of a `### Requirement:` heading in the addon's `openspec/specs/*/spec.md`. The field is for the tools only. A name that matches no heading, or a plan with `covers` and no specs folder to check, SHALL fail validation. The compiler SHALL drop `covers`, so the compiled string is the same with and without it.

#### Scenario: Unknown requirement
- **WHEN** a step covers a name that no spec heading has
- **THEN** validation fails and names the step and the name

#### Scenario: Compiled string
- **WHEN** a plan adds `covers` to a step
- **THEN** the compiled string is byte-identical to the one without it
