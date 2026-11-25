## ADDED Requirements

### Requirement: Collection reads saved variables without luajit and follows the plan
The collector SHALL decode saved-variables files with a pure-Python reader that gives the same JSON as `tools/sv2json.lua`. Given a plan, it SHALL collect the saved-variables files that define the plan's `logs.*.global` names, the plan's addon file and CheckThat's own file; without a plan it SHALL collect the default addon list. It SHALL print each source file's path, modified time and age, and SHALL warn about a plan global that no file defines. It SHALL accept a screenshot time slack in seconds (default 2).

#### Scenario: A plan for another addon
- **WHEN** a plan's log names a global that only a made-up addon's file defines
- **THEN** `collect --plan` copies that file and no unrelated addon's file

#### Scenario: A global nobody defines
- **WHEN** a plan names a global that no collected file defines
- **THEN** `collect` warns and names the global

#### Scenario: Reader and luajit agree
- **WHEN** both read the same fixture
- **THEN** the JSON text is identical

#### Scenario: Slack
- **WHEN** a screenshot lies 1 second outside an attempt and the slack is 0
- **THEN** it counts as matching no attempt
