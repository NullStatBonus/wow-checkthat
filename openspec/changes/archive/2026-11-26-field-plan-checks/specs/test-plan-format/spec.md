## ADDED Requirements

### Requirement: Validation warns when the version step accepts an older build
When the addon's TOC is known, `ct.py validate` and `compile` SHALL read its `## Version:` and warn, without failing, when the first step's `version` fact assertion (`key: version` or `entry.version`) accepts a lower version. The fact value is `major*10000 + minor*100 + patch`. The warning SHALL name the step, the accepted version and the addon's version. The TOC is known from `--addon-src <folder>`, or else from the plan's `offline.toc` when that file exists under the addons folder.

#### Scenario: Plan behind the TOC
- **WHEN** the TOC says `## Version: 1.13.1` and the version step has `op: ge`, `value: 11300`
- **THEN** validation prints `<step>: accepts 1.13.0; the addon is 1.13.1` and exits zero

#### Scenario: Plan matches the TOC
- **WHEN** the version step has `op: ge`, `value: 11301` and the TOC says 1.13.1
- **THEN** validation prints no version warning

#### Scenario: TOC unknown
- **WHEN** there is no `--addon-src` and no `offline.toc` file to read
- **THEN** validation prints no version warning, as before

### Requirement: Validation warns about step references in player text
`ct.py validate` SHALL warn, without failing and naming the step, when its action text, `setup` or `expect` cites a step by number (`check 1.3`, `step 1.3`) or names one of the plan's own step ids. The card shows step titles, not ids, so the player cannot follow such a reference. `notes` and `reviewer` SHALL NOT be checked.

#### Scenario: Check number in expect
- **WHEN** a step's `expect` says "the vendor you opened in check 1.3"
- **THEN** validation prints a warning that names the step and says to describe what the player did

#### Scenario: Step id in setup
- **WHEN** a step's `setup` names another step's id
- **THEN** validation prints the same warning

#### Scenario: On purpose
- **WHEN** a step's `notes` say "on purpose", because the game shows the id in that text (a CheckThat chat line)
- **THEN** validation prints no reference warning for that step

#### Scenario: Reviewer line
- **WHEN** a `reviewer` line names a partner step id
- **THEN** validation prints no reference warning for it
