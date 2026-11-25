# Spec Delta

## ADDED Requirements

### Requirement: Coverage report
`ct.py coverage <plan...> --addon-src <path>` SHALL list every slash subcommand and setting key of the addon source as used or unused, with the ids of the steps that cover each. It SHALL list the `### Requirement:` names of the addon's specs that no step or section covers. A subcommand is covered by a step that names `/alias subcommand` in its action, setup or cleanup. A setting key is covered by a step that names it in that text, in a fact key, or in a state probe. An addon source with no subcommand SHALL be an error. The plans SHALL belong to one addon.

#### Scenario: One unused subcommand
- **WHEN** the addon has three subcommands and the plan uses two
- **THEN** the report lists two as used with their step ids and one as unused

#### Scenario: A fact check covers a setting
- **WHEN** a setting key appears only in a fact assertion
- **THEN** the report lists the setting as used

#### Scenario: Nothing extracted
- **WHEN** the source holds no subcommand
- **THEN** the command fails and says so

### Requirement: Coverage joins run evidence
With `--evidence`, the report SHALL join each plan to its newest finished run of the same addon and plan title. Each used item SHALL be `passed` when a covering step passed, else `failed` when a covering step failed or is unverified, else `never-run`.

#### Scenario: Three outcomes
- **WHEN** one covered item has a passing step, one has a failing step and one has a step the run skipped
- **THEN** they are `passed`, `failed` and `never-run`
