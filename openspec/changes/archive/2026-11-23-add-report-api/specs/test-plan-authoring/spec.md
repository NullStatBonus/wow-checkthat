# Spec Delta

## MODIFIED Requirements

### Requirement: Skill offers issues for missing log evidence
For steps with no log evidence the skill SHALL offer to open issues in the addon's repository. Each issue SHALL name a log line or a fact that the addon could publish with `CheckThat.Report`, the guarded call and its key, and the steps it unlocks. When the addon has no debug log it SHALL offer one issue for the log facility plus one per needed line or fact. It SHALL ask first and SHALL NOT open an issue unasked.

#### Scenario: No log facility
- **WHEN** the author accepts issues for an addon with no debug log
- **THEN** the skill drafts one issue for the facility and one per needed line or fact, each listing the steps it unlocks

#### Scenario: A value with no log line
- **WHEN** a step proves a value that the addon does not log
- **THEN** the skill offers a fact beside a new log line, names the guarded `CheckThat.Report` call and key, and writes no assertion for a fact the addon does not yet report
