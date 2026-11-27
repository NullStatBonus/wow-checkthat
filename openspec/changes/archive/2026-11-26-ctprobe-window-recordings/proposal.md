# Proposal

## Why

DontDoThat's foundation plan needs mocks for vendor, trainer and auction calls (wow-dontdothat #73). CTProbe cannot record them. `/ctp record` runs a fixed list from the chat box, and merchant, trainer and auction calls return nothing unless the matching window is open. The recordings in `tools/recordings/` hold only the Hearthstone and a few client facts. A plan author has no way to get a recorded vendor row. #214 tracks the general fix (record any read-only call). This change is the first concrete use of it.

## What Changes

- **Armed window capture.** `/ctp record arm` makes CTProbe record on the next vendor, trainer and auction house window the player opens. Each window is recorded once per arm. The chat line says what was recorded.
- **Item rows.** The static list gains `GetItemInfo` and `C_Item.GetItemInfo` for one armor and one weapon that sell for more than 1 silver. The probe asks the client to load the item first and records when it arrives, so an uncached item no longer records as nil.
- **Calls recorded** (each only where the client has it, checked with the wow-api tool per client):
  - Vendor: `GetMerchantNumItems`, `GetMerchantItemInfo`, `GetMerchantItemLink` for the first rows.
  - Trainer: `GetNumTrainerServices`, `GetTrainerServiceInfo` and the cost and requirement calls for the first rows.
  - Auction: `GetAuctionItemInfo` (Era), or the `C_AuctionHouse` call Forever has.
- **Read-only allow-list.** The capture calls only what is on a list in the probe. `BuyMerchantItem` is not on it: it spends gold and returns nothing a mock needs. A plan checks the call with a spy in the fake client instead.
- **`GetMoney`** stays recorded by type only (a personal value). A plan mocks it with a literal return.
- **Recording file.** A call may carry an optional `window` key (`merchant`, `trainer` or `auction`). `format` stays 1 and a new `rev: 2` marks the addition. Old files and the old runner keep working.
- **Docs.** `docs/harvesting.md`, `tools/ctprobe/README.md`, `docs/contracts.md`, and a comment on #214.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. CTProbe and the recordings are developer tooling and have no OpenSpec capability. The recording file is a versioned format, so the change is additive and tested for old shapes (see design).

## Impact

- `tools/ctprobe/CTProbe/CTProbe.lua`, `tools/ctprobe/README.md`, `tools/ct.py` (`probe_recordings`), `tools/entry_runner.lua` (reads `format`; unchanged unless `rev` needs a check), `tools/recordings/*.json` (new calls after a game run).
- Tests: `tests/test_ctprobe.lua`, `tools/test_ct.py`, `tests/test_entries.lua`.
- No file under `CheckThat/` changes: no version bump, no changelog.
- A tester must open a vendor, a trainer and the auction house on Era and on Forever.
