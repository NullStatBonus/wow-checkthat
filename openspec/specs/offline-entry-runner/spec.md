# offline-entry-runner Specification

## Purpose
An offline luajit runner loads an addon under the fake client with API mocks, calls entry points the addon registered, and fires fake events. It reads its own spec file, not a plan, and never runs code from the spec.

## Requirements

### Requirement: Offline runner calls registered entries
The runner SHALL load an addon's TOC files under the fake client and call only entries the addon registered through the stub `CheckThat.Entry`, with literal arguments from a spec file. A call to an unregistered name SHALL fail the step.

#### Scenario: Entry returns the expected values
- **WHEN** a step calls a registered entry with literal arguments and expects returns
- **THEN** the step passes only when the returned values equal the expected values

#### Scenario: Entry is expected to throw
- **WHEN** a step expects a throw and the entry raises an error containing the text
- **THEN** the step passes, and it fails when the entry returns normally

### Requirement: Mocks are data and are reported
The runner SHALL set API mocks from the spec before the addon loads, restore the earlier values when the run ends, count each mock's calls, and mark every step result that ran with a mock.

#### Scenario: Mock reaches a captured local
- **WHEN** the addon captured a global in a file-scope local and the mock was set before load
- **THEN** the entry that reads the captured local returns the mocked value

#### Scenario: Late mock misses a captured local
- **WHEN** `mockAfterLoad` sets the mock after load
- **THEN** the captured local still returns the original value and a call-time lookup returns the mocked value

### Requirement: Fake events reach the addon's handlers
The runner SHALL fire a named event with literal arguments at each frame that registered it and has an `OnEvent` script.

#### Scenario: Handler changes addon state
- **WHEN** a step fires a registered event
- **THEN** a later entry call sees the state the handler set

### Requirement: Offline command runs a plan's block
`ct.py offline <plan>` SHALL run the plan's offline block in the runner, resolving `toc` from the plan file's folder. It SHALL print JUnit with one case for each step, exit 1 when a step fails, and exit 2 when the plan has no block or the run cannot start.

#### Scenario: Wrong return
- **WHEN** a call step expects a value the entry does not return
- **THEN** that case fails and the exit code is 1

#### Scenario: Matching plan
- **WHEN** every step matches
- **THEN** the exit code is 0

#### Scenario: No block
- **WHEN** the plan has no offline block
- **THEN** the command exits 2 and says so

### Requirement: Only listed APIs can be mocked
The runner SHALL hold a closed list of mockable API names. A mock for a name not on the list SHALL stop the run before the addon loads and fail with the name. A plan cannot add to the list.

#### Scenario: Unlisted mock
- **WHEN** a plan mocks `loadstring`
- **THEN** the run fails before any addon file loads and nothing is replaced
