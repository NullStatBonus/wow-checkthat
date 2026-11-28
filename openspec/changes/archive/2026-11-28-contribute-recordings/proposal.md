# Contribute a recorded call to the bundled recordings

## Why

`tools/recordings/` holds the calls a plan can mock, and only the maintainer's own runs filled it. A developer who records their own calls with CTProbe (`ct.py recordings -o MyAddon/recordings`) has no way to offer one back short of hand-editing a 100-call JSON file, and no way to know which of their calls the file already covers or which ones do not fit `tools/recordings/signatures.json`. Issue #277 asks for that path: a reviewed slice plus a checklist.

## What changes

`ct.py recordings --contribute` reads the same CTProbe saved variables and prints, between `---8<--- contribute:<client>` markers, the calls the bundled recording lacks or holds in another shape, and that fit `signatures.json`. It writes no file, so it works in an installed copy without `-o`; `GetBuildInfo()` is never sent because the slice header carries the client and build. Every call it leaves out is named with the reason (`already recorded`, `differs from signature`, or the reason CTProbe did not record it in game). `docs/harvesting.md` gains the mode and the checklist to read before pasting a slice into a pull request.

## Impact

- `tools/ct.py`: `contribution`, `bundled_recording`, `recording_shape`, `cmd_contribute`, and the `--contribute` flag on `recordings`.
- `tools/test_ct.py`: a `ContributeRecordings` class (new and changed calls offered, matching and off-signature calls named, no slice when nothing is new, no `-o` needed in an installed copy).
- `docs/harvesting.md`, `docs/authoring-plans.md`: the mode, the checklist and a pointer.
- No addon code, so no version bump, no TOC change and no CHANGELOG entry.
