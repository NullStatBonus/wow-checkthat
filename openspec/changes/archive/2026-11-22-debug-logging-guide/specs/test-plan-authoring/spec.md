# Spec Delta

## ADDED Requirements

### Requirement: Skill guides an addon that has no debug log
When the target addon writes no debug log, the skill SHALL say so once, recommend adding one, and point to the debug-logging guide. It SHALL draft the plan with player checks, SHALL mark the steps that would become log assertions once a log exists, and SHALL NOT invent log lines.

#### Scenario: Addon has no debug log
- **WHEN** the author says the addon has no debug log
- **THEN** the skill recommends adding one, points to the guide, and asks whether to add it now or draft with player checks

#### Scenario: Log added later
- **WHEN** the plan was drafted without a log
- **THEN** each step that would gain a log assertion is marked, so the plan can be upgraded

### Requirement: Skill offers issues for missing log evidence
For steps with no log evidence the skill SHALL offer to open issues in the addon's repository. When the addon has no debug log it SHALL offer one issue for the log facility plus one per needed line, naming the steps each unlocks. It SHALL ask first and SHALL NOT open an issue unasked.

#### Scenario: No log facility
- **WHEN** the author accepts issues for an addon with no debug log
- **THEN** the skill drafts one issue for the facility and one per needed line, each listing the steps it unlocks

### Requirement: A debug-logging guide ships with the skill
The repository SHALL hold `docs/debug-logging.md`, which describes the shared debug-log pattern and what makes a line worth asserting on, with example lines from the sample addons. `make install-skill` SHALL install it in the bundle, and the skill SHALL read it when it judges evidence.

#### Scenario: Guide installed
- **WHEN** the author runs `make install-skill`
- **THEN** the installed bundle holds `docs/debug-logging.md`
