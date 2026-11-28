## ADDED Requirements

### Requirement: Hook steps run the developer's Lua
At level 5 a block MAY name a `hooks` file. The runner SHALL load it once, after the other load checks pass and before the addon loads, and it SHALL return a table of functions. A `{ hook: name }` step SHALL call `hooks[name](ctx, ...)` with the step's `args`, and SHALL judge `returns` and `throws` as for a `call` step; with neither, a hook that returns passes and a hook that raises fails with the error text. A missing file, a file that raises or returns no table, a step naming a function the table lacks, or a hook step without a hooks file SHALL fail the load step before any addon file runs. While a hook runs, every global hidden from addon code SHALL hold the host's value, `require`, `dofile` and `loadfile` included; addon code run through `ctx.fire` or `ctx.advance` SHALL see the hidden names as addon code does, and the addon's own values of those names SHALL be kept across a hook. A global the hooks file reads as nil SHALL NOT be in the nil-read report.

#### Scenario: A hook reads the addon's namespace
- **WHEN** a hook returns `ctx.ns.count` after an event step, and the step expects `returns: [1]`
- **THEN** the step passes when the addon's handler set `ns.count` to 1

#### Scenario: A hook that raises
- **WHEN** a hook calls `ctx.eq(2, 3, "rows")`
- **THEN** the step fails with "rows: expected 3, got 2"

#### Scenario: A missing hook
- **WHEN** a step names `setup` and the hooks file has no `setup`
- **THEN** the load step fails with "hook setup is not in" and the file's path, and no addon file runs

### Requirement: The hook context is a public API
Each hook SHALL get a `ctx` with `ns` (the addon's private namespace of the current load), `client` (`era` or `forever`), `level`, `fire(event, ...)` (returns the number of frames, raises when a handler raises or when the event fails the level 4 event check), `combat(on)` (enters or leaves combat as the fake client models it), `advance(seconds)` (moves the virtual clock and runs the timers due, raises when one raises), `mockCalls(api)` (the count for this group), `eq(got, want, what)` and `same(got, want, what)` (deep, cycle-safe, naming the first differing path). Fields SHALL only be added, never removed or changed in meaning.

#### Scenario: Combat and the clock from a hook
- **WHEN** a hook calls `ctx.combat(true)`, then `ctx.advance(2)`
- **THEN** `InCombatLockdown()` is true in the addon's timer callback that comes due
