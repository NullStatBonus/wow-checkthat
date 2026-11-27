# Tasks

## 1. Signatures and sources

- [x] 1.1 Write `tools/recordings/signatures.json` from Blizzard source and the measured recordings.
- [x] 1.2 Add `signature_problems`, `source` and `RECORDING_REV` 4 in `ct.py`. Add the `confirmed`, `changed`, `differs from signature` and `dropped` lines, and `--merge`.
- [x] 1.3 Tests in `tools/test_ct.py`: each rule of `signature_problems`, the committed files fit their signatures and name their sources, a run confirms or flags a derived entry, and `--merge`. Break each rule once.
- [x] 1.4 Blank the uniqueID of an item link.

## 2. Runner

- [x] 2.1 Add the read-only window calls to `Runner.MOCKABLE`. Test that no buy, learn or bid call is on the list.
- [x] 2.2 `tests/test_entries.lua`: the committed class, gear, plain-trainer and auction-link entries replay through the runner.

## 3. Probe v7

- [x] 3.1 Fix each review finding, with a test that fails without the fix.

## 4. Recordings and docs

- [x] 4.1 Merge the v5 in-game rows and drop the plain-vendor rows of that run. Add authored class trainer rows.
- [x] 4.2 Update `docs/harvesting.md`, `docs/contracts.md`, `docs/authoring-plans.md` and `tools/ctprobe/README.md`.
- [x] 4.3 Run `make test` and `make check`.
