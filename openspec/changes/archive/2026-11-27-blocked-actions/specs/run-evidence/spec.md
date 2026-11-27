## ADDED Requirements

### Requirement: Blocked actions are recorded while a run is open
While a run is open the addon SHALL record each `ADDON_ACTION_BLOCKED`, `ADDON_ACTION_FORBIDDEN`, `MACRO_ACTION_BLOCKED` and `MACRO_ACTION_FORBIDDEN` event as one line `<time>.<counter> [<addon>] <EVENT> <function>` in `global.blocked`, from its own event listener, keeping at most 50 lines and 10 a second. A plan SHALL be able to read the list as a quiet `strings` source.

#### Scenario: A blocked action during a run
- **WHEN** the game fires `ADDON_ACTION_BLOCKED` with `KeepThat` and `CastSpellByName()` while a run is open
- **THEN** `global.blocked` gains a line with `[KeepThat] ADDON_ACTION_BLOCKED CastSpellByName()`

#### Scenario: No run open
- **WHEN** the event fires with no run open
- **THEN** nothing is recorded

### Requirement: The error list does not depend on BugGrabber
The addon SHALL NOT record BugGrabber's copy of a blocked or forbidden action in `global.errors`, so a check of the error list gives the same result with and without BugGrabber.

#### Scenario: BugGrabber holds a blocked action
- **WHEN** BugGrabber's list gains `[ADDON_ACTION_BLOCKED] AddOn 'KeepThat' tried to call ...` and a Lua error
- **THEN** `global.errors` gains the Lua error only
