## Why

Each in-game CTProbe run for #240 found a probe bug that Blizzard's source would have predicted. Most of what a recording holds is published: Blizzard's UI source and API documentation, the wiki and game-data tables cover existence, return order, types and nil conventions. In-game runs are costly, so the tools should take what they can from those sources. They should check recordings against it, and keep a run as a single confirmation.

## What Changes

- `tools/recordings/signatures.json` lists the return names, types, `nilable` and `oneornil` positions of each recorded window and item call per client, with its Blizzard source line. A test fails when a committed recording does not fit, and `ct.py recordings` lists each call that does not fit.
- A recording call may carry `source` (`source`, `wiki`, `database` or `authored`, plus `ref`). `RECORDING_REV` becomes 4 and `format` stays 1. A run that records such a call prints `confirmed` or `changed`, and the game's entry replaces it.
- `ct.py recordings` names each label a run drops. `--merge` keeps them. An item link also loses its uniqueID field.
- The offline runner can mock the read-only vendor, trainer and auction calls (`Runner.MOCKABLE`). The calls that buy, learn or bid stay off the list.
- CTProbe v7, from a review against Blizzard source:
  - The last update of an opening wins.
  - A plain scene takes only its own kind of NPC.
  - Trainer header rows are skipped, and the trainer's kind and filter are recorded.
  - An empty or header-only trainer list stores nothing and names the filter.
  - The auction scene waits for complete rows.
  - Arming clears old window rows and lasts one session.
  - A client without the auction event gets an error entry.
  - Vendor ids come from `GetMerchantItemID`.
  - `C_MerchantFrame.GetItemInfo` is kept whole for #234.
  - `/ctp record status` is new.
- The committed recordings gain the v5 in-game rows: the Era weapon vendor and its item info, the Era auction link, the trainer level requirement, and the balance beside each window. The plain-vendor rows of the run are discarded, because v5 filled them with the same weapon vendor. Authored class trainer rows are added for both clients.

## Impact

Tools, tests, recordings and docs. No addon code (`CheckThat/` untouched), no version bump. A released runner ignores `source` and reads every new label.
