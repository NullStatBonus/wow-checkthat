## MODIFIED Requirements

### Requirement: Addons register entries
CheckThat SHALL provide `CheckThat.Entry(addon, name, fn)`, and `CheckThat.API_VERSION` SHALL be 3. It SHALL return true when it stores the entry and false otherwise. It SHALL refuse an invalid name and a value that is not a function. It SHALL accept a registration while a run is open, because a run survives a reload and CheckThat loads before the addons that register. It SHALL never raise an error to its caller.

#### Scenario: Registered at load
- **WHEN** an addon registers an entry before a run opens
- **THEN** the call returns true

#### Scenario: Registered during a run
- **WHEN** an addon registers an entry while a run is open
- **THEN** the call returns true and the entry is stored
