## MODIFIED Requirements

### Requirement: Draft covers the scope and passes validation
The skill SHALL cover each changed requirement or scenario in the scope that a fake game cannot prove with at least one step, add a regression step for the nearest unchanged behavior, and write the plan for one locale. It SHALL run `tools/ct.py validate` on the draft and report each problem with its step ID. It SHALL list every slash command named in step text in that step's `commands`.

#### Scenario: Validation fails
- **WHEN** `validate` rejects the draft
- **THEN** the skill reports each problem with the step ID and fixes the draft before review

#### Scenario: Command named in text
- **WHEN** a step text names a slash command
- **THEN** the step lists it in `commands`

## ADDED Requirements

### Requirement: Skill scopes a plan before it drafts
Before it drafts or converts a manual test document, the skill SHALL ask for each candidate check whether a unit test already proves it, give no plan step to logic a unit test proves, base the depth answer on measured coverage, and offer an essential draft first.

#### Scenario: Converting a manual document
- **WHEN** the author asks to convert a manual test document
- **THEN** the skill lists which checks a unit test already proves and drafts only the rest

### Requirement: Skill splits a large scope into a plan set by area
The skill SHALL keep a plan to at most 25 steps and a section to at most 10. It SHALL split a larger scope into a plan set by area. Each plan SHALL have its own version, setup and final no-Lua-error step and its own section range, and the plans SHALL be imported and finished one at a time.

#### Scenario: Scope too large for one plan
- **WHEN** the essential steps are more than 25
- **THEN** the skill drafts a plan set by area and names the import order

### Requirement: Skill recommends a test-settings mode
The skill SHALL ask whether the plan depends on the addon's settings. When it does, the skill SHALL recommend a test-settings mode in the addon, with a setup step that runs debug on, the test-settings command and `/reload` in that order, and a last step that turns the mode off and asserts the restore line. It SHALL NOT recommend per-step setting commands that overwrite the tester's own settings.

#### Scenario: Plan depends on settings
- **WHEN** the author says a step depends on an addon setting
- **THEN** the skill recommends the test-settings mode and drafts the setup and last steps in that order
