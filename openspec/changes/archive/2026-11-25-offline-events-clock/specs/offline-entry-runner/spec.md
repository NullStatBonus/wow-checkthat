## MODIFIED Requirements

### Requirement: Runner answers by the plan's offline level
The offline block MAY declare `level`, 1, 2, 3 or 4. A block without `level` SHALL run at level 1, so its results do not change: `GetBuildInfo` returns interface 11507 and `issecurevariable` returns false for every name. At level 2 and above the runner SHALL make `GetBuildInfo` return, as its interface number, the number on the TOC's `## Interface:` line, and the key SHALL count only at the start of a line, so the same text inside another line, such as `## Notes:`, is ignored. When the line lists several numbers, the first one SHALL be used. At level 2 and above `issecurevariable` SHALL return true for each global the fake client set up before addon code ran, and false with "Addon" for any other global. Level 3 SHALL add the game's load order (see "Level 3 loads the addon as the game does"), and level 4 the event list and the clock (see "Level 4 checks events against the client" and "Level 4 runs timers on a virtual clock"). Any other `level`, a `reload` step, `groups` or `savedVariables` below level 3, and a `wait` step below level 4, SHALL fail the load step and no addon file SHALL run. The JSON result SHALL carry the level and the interface the addon read. `ct.py offline` SHALL print a warning to stderr when the block has no `level`.

#### Scenario: Era and Forever interfaces at level 2
- **WHEN** a block with `level: 2` names a TOC that says `## Interface: 11509`, and another names one that says `## Interface: 16001`
- **THEN** the addon reads 11509 in the first run and 16001 in the second, and the JSON result carries that number

#### Scenario: Block without a level
- **WHEN** a block has no `level`
- **THEN** the addon reads interface 11507, `issecurevariable("CreateFrame")` is false, and `ct.py offline` prints the level warning

#### Scenario: Unknown level
- **WHEN** a block says `level: 5`
- **THEN** the load step fails with "offline level 5 is not supported" and no addon file runs

#### Scenario: Reload below level 3
- **WHEN** a block at level 2 holds a `reload` step
- **THEN** the load step fails and no addon file runs

#### Scenario: Level 2 sends no login events
- **WHEN** a block at level 2 fires ADDON_LOADED in an `event` step
- **THEN** the handler runs once, and `IsLoggedIn()` is true during load

#### Scenario: Wait below level 4
- **WHEN** a block at level 3 holds a `wait` step
- **THEN** the load step fails with "a wait step needs offline level 4" and no addon file runs

## ADDED Requirements

### Requirement: Level 4 checks events against the client
At level 4 the runner SHALL read the event list of the client the TOC's interface names: `tools/events/era.json` below 16000 and `tools/events/forever.json` from 16000. A missing list SHALL fail the load step. `RegisterEvent` and `RegisterUnitEvent` SHALL raise `Frame:RegisterEvent(): Attempt to register unknown event "NAME"` for an event the list lacks. Before any addon file runs, an `event` step SHALL fail the load step when the list lacks its event, or when the event is documented and the step gives more values than the event carries or fewer than it always carries. Below level 4 any event name SHALL register and fire.

#### Scenario: Unknown event registered
- **WHEN** addon code at level 4 registers `NOT_AN_EVENT`
- **THEN** the call raises the unknown-event error, and registering `MERCHANT_SHOW` works

#### Scenario: Unknown event step
- **WHEN** a level 4 block fires `NOT_AN_EVENT`
- **THEN** the load step fails with "the client has no event NOT_AN_EVENT" and no addon file runs

#### Scenario: Missing value
- **WHEN** a level 4 block fires `BAG_UPDATE` with no values
- **THEN** the load step fails and names the event, the values it carries and the values the step gives

### Requirement: Level 4 runs timers on a virtual clock
At level 4 `GetTime` SHALL start at 1 and `time()` at a fixed epoch, and both SHALL follow a virtual clock. A `wait` step SHALL move the clock on by its seconds and run each `C_Timer.After`, `C_Timer.NewTimer` and `C_Timer.NewTicker` callback that comes due, in order of due time and then of creation, with the clock at each callback's due time. A callback a timer makes SHALL run in the same wait when it comes due. `NewTimer` and `NewTicker` SHALL return a handle with `Cancel` and `IsCancelled` and pass it to the callback, and a ticker SHALL stop after its iterations. A callback that throws SHALL fail the wait step with the error after the other callbacks ran. The clock SHALL go on across a reload, its timers SHALL not, and each group SHALL start at 1. Below level 4 `GetTime` SHALL stay 1 and timers SHALL only queue.

#### Scenario: Timer fires on time
- **WHEN** an entry schedules `C_Timer.After(2, fn)` and the block waits 1.5 seconds, then 0.5 seconds more
- **THEN** `fn` has not run after the first wait and has run with `GetTime()` 3 after the second

#### Scenario: Ticker and cancel
- **WHEN** a ticker of 1 second with 3 iterations and a cancelled timer are made, and the block waits 10 seconds
- **THEN** the ticker ran 3 times and the cancelled timer never ran

#### Scenario: Reload
- **WHEN** a timer is pending and the block waits 2 seconds, then reloads
- **THEN** `GetTime()` is 3 after the reload and the timer never runs
