## Why

Issue #234: a recording keeps scalar returns only. On Forever the vendor row (`C_MerchantFrame.GetItemInfo`) and every auction house result (`C_AuctionHouse`) are tables. So a DontDoThat offline block has no Forever vendor prices and no Forever auction data, and #240 is not useful without them.

## What Changes

- CTProbe v8:
  - It copies a table return three levels deep with up to 32 keys, and marks a partial copy `cut`.
  - It stores table arguments (an auction `itemKey`) with the call.
  - It records three Forever auction scenes from their events: `browse`, `itemsearch` and `commodity`. The last search wins while the auction house is open.
- `ct.py recordings` (rev 5):
  - It keeps a table return as JSON: a Lua array becomes a list and a nil field is a missing key.
  - It reads stored arguments and skips a cut table.
  - It empties `owners`, removes `bidder`, and anonymizes links inside tables.
- `tools/recordings/signatures.json` gains `structures` from Blizzard's generated documentation. A table return is checked field by field.
- The offline runner can mock `C_MerchantFrame.GetItemInfo` and the read-only `C_AuctionHouse` result calls. Each call gets its own copy of a table return, and a table argument matches by value.
- Authored Forever vendor rows and auction results go into the committed recording, marked with their source.

## Capabilities

### Modified Capabilities
- `offline-entry-runner`: mocks may take and return tables.

## Impact

Tools, tests, recordings and docs. No addon code, no version bump. A rev 4 or older file loads as before. A released runner reads a table return as the decoded JSON table.
