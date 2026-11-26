## ADDED Requirements

### Requirement: Plan may declare its purpose
A plan MAY set `purpose` to `foundation` (the release gate: the systems every feature depends on, run by one character) or `feature` (deep on one feature, run when it changes). The field is for the tools only. Any other value SHALL fail validation. The compiler SHALL drop `purpose`, so the compiled string is the same with and without it.

#### Scenario: Unknown purpose
- **WHEN** a plan sets `purpose: release`
- **THEN** `ct.py validate` fails

#### Scenario: Compiled string
- **WHEN** a plan adds `purpose: foundation`
- **THEN** the compiled string is byte-identical to the one without it

### Requirement: Validation warns about technical wording in a plan with a purpose
When a plan declares `purpose`, `ct.py validate` SHALL warn, without failing and naming the step ID, when a step's action text or `expect` names a slash command, or when its `expect` speaks of the log. Color codes SHALL NOT hide a command. A plan without `purpose` SHALL get none of these warnings.

#### Scenario: Command in action text
- **WHEN** a plan with `purpose: feature` has a step whose action text is "Enter |cff99ccff/cvn test sell|r."
- **THEN** validation prints a warning that names the step and says to keep commands behind Run, and exits zero

#### Scenario: Log in Expect
- **WHEN** a plan with a purpose has a step whose `expect` is "the addon logs the route"
- **THEN** validation prints a warning that names the step and says Expect states what is on screen

#### Scenario: Logging in is not the log
- **WHEN** a step's `expect` is "you log in without an error", or says "log out" or "log on"
- **THEN** validation prints no wording warning for it

#### Scenario: Log words
- **WHEN** a step's `expect` says "log", "logs", "logged" or "logging"
- **THEN** validation warns for it

#### Scenario: Copy-slash step
- **WHEN** a plan with a purpose has a `copy-slash` step, whose action text is the command itself
- **THEN** validation prints no command warning for its action text

#### Scenario: Plan without a purpose
- **WHEN** a plan without `purpose` has a command in its action text
- **THEN** validation prints no wording warning, as before

### Requirement: Validation warns about a long foundation plan
When a plan declares `purpose: foundation`, `ct.py validate` SHALL warn, without failing, when it has more than 12 steps, counting each case as a step. The warning SHALL suggest one step per pillar and moving the rest to a feature plan. The 25-step and 10-step warnings SHALL still apply to every plan.

#### Scenario: Foundation plan over 12 steps
- **WHEN** a plan with `purpose: foundation` has 13 steps
- **THEN** validation prints a warning that names 13 steps and feature plans, and exits zero

#### Scenario: Feature plan of 13 steps
- **WHEN** a plan with `purpose: feature` has 13 steps
- **THEN** validation prints no foundation size warning
