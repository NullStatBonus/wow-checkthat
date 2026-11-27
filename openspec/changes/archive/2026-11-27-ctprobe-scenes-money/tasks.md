# Tasks

## 1. Probe

- [x] 1.1 Tests in `tests/test_ctprobe.lua` cover these: gear and plain vendor scenes, money with its value, row item info and its late delivery, a link not loaded yet, class and profession trainers with ten and three rows, and the auction link.
- [x] 1.2 Implement scenes, `GetMoney`, item info, `GetTrainerServiceLevelReq` and `GetAuctionItemLink` in `CTProbe.lua`. Bump `VERSION` to 5. Break each behavior once; each test failed for its reason.

## 2. Tools

- [x] 2.1 `ct.py`: a scene name before the call in `CALL_LABEL`, and `RECORDING_REV` 3. Tests in `tools/test_ct.py`: a scene label keeps its api and money, an upper-case scene is refused, and the offline runner reads a rev 3 scene label.
- [x] 2.2 `entry_runner.lua`: the function check skips a scene name.
- [x] 2.3 `tests/test_entries.lua`: the committed files may be rev 3, and `GetMoney` is allowed only under a window scene.

## 3. Docs

- [x] 3.1 `tools/ctprobe/README.md`, `docs/harvesting.md`, `docs/authoring-plans.md`, `docs/contracts.md` (source review), schema description.
- [x] 3.2 `make test` and `make check`.
