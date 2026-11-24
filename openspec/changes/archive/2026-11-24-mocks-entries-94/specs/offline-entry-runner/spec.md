## ADDED Requirements

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
