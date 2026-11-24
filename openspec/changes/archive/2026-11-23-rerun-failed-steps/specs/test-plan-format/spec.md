## ADDED Requirements

### Requirement: The id failed is reserved
Validation, in the compiler and on import, SHALL reject the id `failed` as a category id, and as a section id when the plan declares no categories, because `/ct rerun failed` uses the name.

#### Scenario: A category called failed
- **WHEN** a plan declares a category with the id `failed`
- **THEN** validation fails and says the id is reserved
