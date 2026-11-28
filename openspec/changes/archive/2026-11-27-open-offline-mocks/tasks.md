# Tasks

## 1. Offline runner

- [x] 1.1 Add `H.luaFunction(name)` to `tests/harness.lua` (base functions and `luaAlias` aliases, not `HELPERS`). Add `Runner.UNMOCKABLE` and `Runner.mockable(api, surface)` to `tools/entry_runner.lua`, and use it for the allow-list check. Test in `tests/test_entries.lua`: a surface function mocks at level 5 and fails at level 4; `loadstring`, `string.format`, `strsub`, `InCombatLockdown`, `hooksecurefunc` and `C_Timer.After` fail at level 5.
- [x] 1.2 Read `spec.recordings/<client>.json` beside the bundled file; the addon's entry wins; errors name the path. Test: a recording only in the addon's file, an entry in both, a missing file, a bad format.

## 2. Plan format and ct.py

- [x] 2.1 Add `offline.recordings` (string) to `schema/test-plan.schema.json`, valid only at level 5. Test in `tools/test_ct.py`.
- [x] 2.2 Resolve `recordings` in `offline_plan` inside the addons folder, refusing a path that leaves it. Test both.
- [x] 2.3 `ct recordings` from an installed bundle without `-o` exits 2 and names `-o`. A call stored with a `player` argument is left out. Test both.

## 3. CTProbe

- [x] 3.1 `/ctp record <call>`: parse the name and literal arguments, check the prefix rule and the block list, record with `GetBuildInfo()`, type only for personal values, keep the entry across `/ctp record`. Test in `tests/test_ctprobe.lua`: a read-only call, a refused name, code in an argument, quoted text with a comma, a player unit, a return holding the name, and the entry kept.
- [x] 3.2 Add `tools/ctprobe` to `BUNDLE_DIR` and check the toolkit zip holds the probe in `tools/test_ct.py`.

## 4. Docs

- [x] 4.1 `tools/ctprobe/README.md` (shipped, `/ctp record <call>`), `docs/authoring-plans.md` (the open mock rule, `recordings`), `docs/harvesting.md` or `docs/skills.md` (record your own calls), `skills/ct-test-plan/SKILL.md` (how to get a recording), `docs/test-plan.md` (a manual check of `/ctp record <call>`).
- [x] 4.2 Run `make test` and `make check`; confirm no file under `CheckThat/` changed.
- [x] 4.3 Move "Record your own calls" to `docs/authoring-plans.md` (bundled) with the CTProbe path for each install kind; the skill gives the full path; `recordings` joins the stable commands; a test checks every `$CT/` path a skill names ships in the bundle.
- [x] 4.4 Fix the developer doc review: one runnable recording example for both clients, export limits and a privacy check, the first-plan steps through offline and results, one line per offline level, the CTProbe README opening, the README plugin install, the skill's offline items and runnable `--client both`, `docs/tools-guide.md` on offline fakes, and `/reload` as its own manual check.
