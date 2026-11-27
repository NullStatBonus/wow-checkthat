# Design

## Context

`/ctp record` (`record()` in `tools/ctprobe/CTProbe/CTProbe.lua`) walks `FIXTURES` once. Each entry is `{ label, function, typeOnly }`. The result goes to `CTProbeDB.fixtures[label]`. `ct.py recordings` (`probe_recordings`) turns that into `tools/recordings/<client>.json`. `tools/entry_runner.lua` reads the file and requires `format == 1`.

`probe_recordings` skips: errors, type-only values, a call on `player`, a label argument that is not a number, boolean or plain word, and a return that is a table or function. Window calls return scalars, so most pass. A string argument such as `"list"` must be written as the plain word `list` in the label.

## Decisions

1. **Armed capture, not a longer list.** `/ctp record arm` sets `CTProbeDB.armed` and registers `MERCHANT_SHOW`, `TRAINER_SHOW` and `AUCTION_HOUSE_SHOW` (and the auction result event). Each handler records its calls and disarms that window. Why: the calls return nothing without the window, and a chat command typed with a window open is awkward and easy to get wrong. Alternative rejected: C, label-driven `/ctp record <label>` (#214). It is the general fix. This change feeds it and does not block it.
2. **A separate allow-list for window calls**, kept next to `FIXTURES`. It names read-only calls only. The test loads the probe, reads the list and fails when it holds a name from a deny set (`BuyMerchantItem`, `PickupMerchantItem`, `CloseMerchant`, `BuyTrainerService`, `PlaceAuctionBid`, `StartAuction`). Why: it keeps a later edit from adding a call that changes state.
3. **`BuyMerchantItem` is not recorded.** A recording of a call that returns nothing is empty, and calling it buys. The plan checks the arguments with a spy in the fake client.
4. **Item cache.** The armor and weapon ids are not known to sell above 1 silver until a recording shows their sell price. The probe records a short candidate list (Lionheart Helm 12640, Arcanite Reaper 12784), and the reviewer keeps those with a sell price above 100 copper (task 5.3). For the item rows, the probe calls `C_Item.RequestLoadItemDataByID` (or the client's equivalent, checked with `get_api`), waits for `GET_ITEM_INFO_RECEIVED`, then records. A row that stays nil is recorded as nil and the log says so. Item ids: pick candidates, read `sellPrice` from the recording, and keep an armor and a weapon with a sell price above 100 copper (1 silver).
5. **Per-client calls.** The generated API docs (`get_api`) list only `C_` calls, so the legacy globals were checked with the source search instead (result in `docs/contracts.md`). Forever ships both Vanilla and Mainline interface files, so the probe decides at run time: it records a call only when the function exists, and never picks a path by client name. Forever's auction and `C_MerchantFrame.GetItemInfo` return tables, which a recording does not keep (see Non-Goals), so they stay unrecorded.
6. **File format, additive.** A call gets an optional `window`. The file keeps `format: 1` (the runner rejects any other value, so raising it would break a released runner) and gains `rev: 2`. The runner ignores unknown keys, and a test reads a rev-1 file. A recording from a window is a shape sample from one vendor, trainer or auction house, not fixed data. The docs say so.
7. **Privacy.** Vendor and trainer rows hold item and spell names, prices and links, which are game data. Item links go through `anonymize_link`. A name that identifies a character stays type-only. The existing test that checks committed recordings for a character or realm name covers the new calls.
8. **Harness fakes are out of scope.** `tests/harness.lua` has no merchant, trainer or auction fake. A mock can already name a recording, so the offline runner can replay one. A fake that behaves like a window is a separate change.

## Risks

- A window event can fire before the client fills the rows. The handler records on the event and again on the next `MERCHANT_UPDATE` or result event only if the first read was empty.
- Era and Forever differ in trainer and auction APIs. Mitigation: per-client check (decision 5), and `/ctp record arm` logs each call it skipped.

## Non-Goals

- #214: label-driven recording of any read-only call, and shipping CTProbe in the skill bundle.
- The in-game recording itself and the measured rows in `docs/contracts.md`: #231.
- Merchant, trainer and auction fakes in the harness.
- Recording table returns (Forever auction and `C_MerchantFrame.GetItemInfo`). It needs a recording format change; open an issue if DontDoThat needs it.
- Any change under `CheckThat/`.
