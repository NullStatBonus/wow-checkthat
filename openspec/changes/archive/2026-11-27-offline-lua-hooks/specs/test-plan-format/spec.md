## MODIFIED Requirements

### Requirement: Plan may carry an offline block
A plan MAY hold a top-level `offline` object with `toc`, optional `tocs` (an object with `era` and `forever` TOC paths, at least one), `mocks`, `mockAfterLoad`, `level` (1 to 6), `savedVariables`, `recordings` (the addon's recordings folder, a path inside the addons folder like `toc`) and `hooks` (the addon's Lua hooks file, a path inside the addons folder like `toc`), and either `steps` or `groups`. Each step is one of a `call` (addon, entry, literal `args`) with `returns` or `throws`, an `event` (name, literal `args`), a `mockCalls` count, a `hook` (a function name in the hooks file, with literal `args` and `returns` or `throws`), `reload: true`, `wait` (seconds, 0 to 86400), or a `tooltip` check (`lines` as a count, or `equals` or `contains` text with an optional `line`). `predicts` (optional) maps a plan step id to a non-empty list of offline step ids (`offline.N`, or `offline.G.N` in a group); validation SHALL fail an id that names no plan step or no offline step. `savedVariables` maps a global name to a literal value. A mock entry holds `args` and `returns`, or instead a `recording` (a label such as `GetItemInfo(6948)`) that takes both from a recorded call for the client the block runs on; it SHALL NOT hold `recording` with `args` or `returns`. Each group holds `steps` and optional `label`, `mocks` and `savedVariables`. `reload`, `groups` and `savedVariables` SHALL be valid only with `level` 3 or more, `wait` only with `level: 4`, and `tocs`, `recordings`, `hooks`, `tooltip` and `hook` steps and a mock `recording` only with `level: 5`. The runner SHALL pass a `tooltip` step when the lines on `GameTooltip` match and fail it with the lines it found when they do not. A `tooltip` step holds `lines`, or `equals` or `contains` (not both) with an optional `line`, and no other mix. `ct.py offline --client` reads `tocs`; without that option only `toc` runs, and a plan without `tocs` validates and runs as before. Validation SHALL reject any other shape. Compile SHALL remove the block, so the compiled string and its digest do not contain it.

#### Scenario: Valid block
- **WHEN** a plan holds an offline block with one call step
- **THEN** `ct.py validate` passes

#### Scenario: Unknown step field
- **WHEN** an offline step holds a field the schema does not list
- **THEN** `ct.py validate` fails

#### Scenario: Compile drops the block
- **WHEN** the same plan is compiled with and without the block
- **THEN** both compiled strings are equal

#### Scenario: Offline level
- **WHEN** an offline block says `level: 6`, and another says `level: 7`
- **THEN** validation passes the first and fails the second

#### Scenario: One TOC for each client
- **WHEN** a block at level 5 holds `tocs` with an `era` path, a `forever` path, or both, and another block holds `tocs` with a `retail` key or an empty object
- **THEN** validation passes the first and fails the second

#### Scenario: Offline predictions
- **WHEN** a block holds `predicts` that maps a plan step to `offline.1`, and another maps a plan step to `offline.9` in a block of two steps, or maps an unknown plan step
- **THEN** validation passes the first and fails the others

#### Scenario: Mock from a recording
- **WHEN** a level 5 block mocks `GetItemInfo` with `recording: GetItemInfo(6948)`, and another mocks it with a `recording` and `returns`, or with a `recording` at level 4
- **THEN** validation passes the first and fails the others

#### Scenario: Tooltip step
- **WHEN** a level 5 block holds a `tooltip` step with `lines: 3`, with `contains`, or with `line` and `equals`, and another holds an empty `tooltip`, `line` alone, or `lines` with `contains`
- **THEN** validation passes the first and fails the second

#### Scenario: Tooltip below level 5
- **WHEN** a block at level 4 or below, or with no level, holds a `tooltip` step, in its steps or in a group
- **THEN** validation fails

#### Scenario: Tocs below level 5
- **WHEN** a block at level 4 or below, or with no level, holds `tocs`
- **THEN** validation fails

#### Scenario: Reload below level 3
- **WHEN** a block at level 2 holds a `reload` step, `groups` or `savedVariables`
- **THEN** validation fails

#### Scenario: Wait below level 4
- **WHEN** a block at level 3 holds a `wait` step, in its steps or in a group
- **THEN** validation fails

#### Scenario: Steps and groups
- **WHEN** a block holds both `steps` and `groups`
- **THEN** validation fails

#### Scenario: The addon's recordings folder
- **WHEN** a level 5 block holds `recordings: MyAddon/recordings`, another holds it at level 4, and another holds `recordings: ../elsewhere`
- **THEN** validation passes the first and fails the second, and `ct.py offline` refuses the third because it leaves the addons folder

#### Scenario: Hook steps
- **WHEN** a level 5 block holds `hooks: MyAddon/tests/offline_hooks.lua` and a step `{ hook: rows, returns: [3] }`, another holds a `hook` step at level 4, another a `hook` step with both `returns` and `throws`, and another a `hook` step with no `hooks`
- **THEN** validation passes the first and fails the others
