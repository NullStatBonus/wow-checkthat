## ADDED Requirements

### Requirement: Skill never cites a step number in player text
The skill SHALL refer to an earlier step in action text, `setup` and `expect` by what the player did there (for example "the vendor you walked to after the first sell question"), never by a step number or id. It SHALL run `validate` with `--addon-src` when the addon source is at hand, so a version step behind the TOC is caught.

#### Scenario: Step depends on an earlier one
- **WHEN** a step needs the window an earlier step opened
- **THEN** its text names that window by what the player did, and `validate` prints no reference warning
