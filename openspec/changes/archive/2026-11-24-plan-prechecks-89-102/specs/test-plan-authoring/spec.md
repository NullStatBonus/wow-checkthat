# Spec Delta

## ADDED Requirements

### Requirement: Skill sets auto and manual steps apart
The skill SHALL ask the author for each step whether it is auto or manual, SHALL end the `expect` text of a manual step with the press it needs, and SHALL default an auto step's `timeout` to 120 seconds while saying it counts from when the step opens.

#### Scenario: Manual step text
- **WHEN** the skill drafts a manual step
- **THEN** its `expect` text ends with the press that records the result

### Requirement: Skill replays the compiled plan before review
After `compile` the skill SHALL run `tests/replay_plan.lua` on the plan and SHALL show the result in the review. A plan whose replay reports a problem SHALL NOT be called final.

#### Scenario: A step never settles
- **WHEN** the replay reports a step that does not settle
- **THEN** the review lists the step and the plan stays open

### Requirement: Skill warns about a stale bundle
When `$CT/VERSION` and a checkout both exist and differ, the skill SHALL warn that the bundle is stale and name `make install-skill`.

#### Scenario: Bundle older than checkout
- **WHEN** `$CT/VERSION` is 0.16.0 and the checkout is 0.17.0
- **THEN** the skill tells the author to run `make install-skill`
