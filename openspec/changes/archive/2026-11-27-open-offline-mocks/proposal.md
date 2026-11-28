## Why

An offline block can mock only a closed list of about 40 calls, mostly vendor, trainer and auction ones, and only the maintainer can record what the game answers. A developer whose addon reads any other game call cannot test it offline with real answers (#214). This is the next step to a complete toolkit for addon developers.

## What Changes

- At offline level 5 and up, a mock may name any function the client's surface (`tools/clients/<client>.json`) lists, except Lua's own functions and the functions the fake client's security, combat and timer model rests on. Below level 5 the closed list stays. A plan that this used to refuse now runs; no plan that ran changes its result.
- An offline block may name the addon's own recordings folder (`recordings`, level 5). The runner reads `<folder>/<client>.json` beside the bundled recordings, and the addon's entry wins for the same label.
- CTProbe ships in the skill bundle, the plugin and the toolkit zip (`tools/ctprobe`). It is a development addon and is never published to CurseForge or Wago.
- `/ctp record <call>`, such as `/ctp record GetItemInfo(6948)`, records one call. The function name must start with Get, Is, Has, Can or Num, or be a `Unit` read, and a short block list refuses the few such names that change state. Arguments are literal values only (numbers, text, true, false, nil), never run as code. A call on a player unit, or a return that holds the character's name, realm, money or GUID, is recorded by type only.
- `ct recordings` becomes a stable command, since developers now run it. The recording steps live in `docs/authoring-plans.md`, which the bundle ships.
- `ct recordings` keeps working as before. When it runs from an installed bundle without `-o`, it stops and asks for a folder in the addon's repository, so a recording is not written into the plugin cache.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `offline-entry-runner`: the mock allow list opens at level 5 to the client's surface; the runner reads the addon's recordings folder.
- `test-plan-format`: the offline block takes an optional `recordings` folder at level 5.
- `test-plan-authoring`: CTProbe ships in the bundle; `/ctp record <call>` records one read-only call; `ct recordings` asks for `-o` from an installed bundle.

## Impact

- `tools/entry_runner.lua` (mock rule, recordings folder), `tests/harness.lua` (names Lua's own functions for the rule), `tools/ct.py` (resolve `recordings`, the installed-bundle `-o` rule, a player argument in stored args), `schema/test-plan.schema.json`.
- `tools/ctprobe/CTProbe/CTProbe.lua` (`/ctp record <call>`), `tests/test_ctprobe.lua`, `tests/test_entries.lua`, `tools/test_ct.py`.
- `Makefile` `BUNDLE_DIR` adds `tools/ctprobe`.
- Docs: `tools/ctprobe/README.md`, `docs/authoring-plans.md`, `docs/harvesting.md`, `docs/skills.md`, `skills/ct-test-plan/SKILL.md`, `docs/test-plan.md` (a manual check of `/ctp record <call>`).
- No file under `CheckThat/` changes, so there is no version bump.
