# Spec Delta

## ADDED Requirements

### Requirement: Main skill text is addon-neutral
The skill's main text SHALL hold the rules that apply to any addon and SHALL point to its reference file for CheckThat's supported-addon list, log sources and version-check recipes.

#### Scenario: Author of another addon
- **WHEN** an author of another addon reads the main skill text
- **THEN** it names no CheckThat internal file or table, and each detail is one pointer away in the reference
