## Why

Issue #240: a downstream addon's offline blocks need calls that the CTProbe recordings do not hold yet. These are the Era auction link, a class trainer with several ranks, a vendor that sells armor or weapons with the item info for its rows, and the player's money beside each vendor. The Blizzard API documentation covers only the `C_` calls, so these legacy globals need a recording.

## What Changes

- CTProbe v5 `/ctp record arm` records two scenes per window: `gear` and the plain vendor, `class` and the plain trainer. The auction list stays one scene. The plain scene keeps the v4 labels. The other scene's labels start with its name (`gear:GetMerchantItemInfo(1)`).
- A class trainer keeps ten rows, so the ranks of one spell show. The trainer also records `GetTrainerServiceLevelReq`.
- Auction rows also record `GetAuctionItemLink`.
- Each vendor and trainer scene records `<scene>:GetMoney()` with its value. Each vendor row's item records `GetItemInfo` and `C_Item.GetItemInfo`. The probe waits when an item link is not loaded yet.
- `ct.py recordings` reads a label with a scene name and writes `rev: 3`. `format` stays 1.
- The offline runner accepts a `recording` label with a scene name for the mocked function.

## Impact

- `tools/ctprobe/CTProbe/CTProbe.lua`, `tools/ct.py`, `tools/entry_runner.lua`, tests, docs and the schema description.
- No addon code changes (`CheckThat/` untouched), so the version is not bumped.
- Compatibility: rev 2 and older recordings load as before. A rev 3 file adds only new labels. A runner from before this change reads the plain labels and reports a scene label as "for another function".
