## ADDED Requirements

### Requirement: Skill ends a plan with a run-scoped error check
The skill SHALL draft the final no-Lua-error step of a plan with `scope: run` on the quiet `errors` source, and SHALL NOT tell the author that the step also sees errors from earlier runs or plans.

#### Scenario: Foundation plan
- **WHEN** the skill drafts a foundation plan
- **THEN** its last step checks the `errors` source with `scope: run`
