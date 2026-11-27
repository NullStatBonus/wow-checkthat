## MODIFIED Requirements

### Requirement: Mocks are data and are reported
The runner SHALL set API mocks from the spec before the addon loads, restore the earlier values when the run ends, count each mock's calls, and mark every step result that ran with a mock. A mock's `args` and `returns` MAY hold tables (JSON objects and lists). A table argument SHALL match by value, and each call SHALL return its own copy of a table return.

#### Scenario: Mock reaches a captured local
- **WHEN** the addon captured a global in a file-scope local and the mock was set before load
- **THEN** the entry that reads the captured local returns the mocked value

#### Scenario: Late mock misses a captured local
- **WHEN** `mockAfterLoad` sets the mock after load
- **THEN** the captured local still returns the original value and a call-time lookup returns the mocked value

#### Scenario: Table return
- **WHEN** a mock of `C_MerchantFrame.GetItemInfo` returns an object, and the addon changes the table it got
- **THEN** the next call returns the object as the mock wrote it

#### Scenario: Table argument
- **WHEN** a mock of `C_AuctionHouse.GetItemSearchResultInfo` lists an itemKey object as its first argument
- **THEN** a call with an equal itemKey gets the mocked return and a call with another itemKey gets nothing
