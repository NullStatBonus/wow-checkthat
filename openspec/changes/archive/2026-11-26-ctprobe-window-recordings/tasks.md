# Tasks

## 1. Check the calls per client

- [x] 1.1 Look up each vendor, trainer and auction call for `classic_era` and `forever` (source search, since `get_api` lists only `C_` calls). Record the result in `docs/contracts.md`.
- [x] 1.2 Choose candidate armor and weapon item ids (12640, 12784). Task 5.3 keeps those whose recorded sell price is above 100 copper.

## 2. Probe

- [x] 2.1 Write the failing test in `tests/test_ctprobe.lua`: `/ctp record arm` then `MERCHANT_SHOW` records the vendor calls into `CTProbeDB.fixtures`, once.
- [x] 2.2 Same for `TRAINER_SHOW` and the auction event.
- [x] 2.3 Test: with nothing armed, the window events record nothing.
- [x] 2.4 Test: the allow-list holds no name from the deny set, and the probe calls nothing outside the list.
- [x] 2.5 Test: the item rows request the item first and record when `GET_ITEM_INFO_RECEIVED` fires. An item that never arrives records nil and logs it.
- [x] 2.6 Implement `arm`, the window handlers, the allow-list and the item rows in `CTProbe.lua`. Bump the probe `VERSION`. Break each behavior once and check the test fails for the right reason.
- [x] 2.7 Add `arm` to the `/ctp` usage line and `tools/ctprobe/README.md`.

## 3. Recordings tool

- [x] 3.1 Test in `tools/test_ct.py`: `probe_recordings` keeps a `window` tag, and a label like `GetAuctionItemInfo(list,1)` is read back.
- [x] 3.2 Test: a rev-1 recording file (no `window`, no `rev`) still loads in `tests/test_entries.lua`, and a file with `rev: 2` and `window` loads in the old way.
- [x] 3.3 Implement the `window` key and `rev: 2` in `probe_recordings`. Keep `format: 1`.

## 4. Docs

- [x] 4.1 `docs/harvesting.md` (Record calls): the arm steps, the shape-not-fixed-data note, and `GetMoney` by type only.
- [x] 4.2 Comment on #214: armed window capture is its first use.
- [x] 4.3 Keep README short; run `make test` (it checks the docs for unrelated addon names) and `make check`.


The in-game recording, the measured rows for `docs/contracts.md` and the note to wow-dontdothat #73 moved to #231, because they need a tester and a game client.
