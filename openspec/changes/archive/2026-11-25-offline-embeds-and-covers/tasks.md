# Tasks

## 1. Shared TOC file list

- [x] 1.1 Add `H.tocFiles(toc)` to `tests/harness.lua` (design D1 to D3) and make `H.loadToc` run its list. Verify `luajit tests/test_smoke.lua` passes unchanged.
- [x] 1.2 Add an `embeds.xml` to `tests/fixtures/MockAddon` that names a small library file and includes a second XML file naming another, with one `Script` line inside an XML comment. List `embeds.xml` in `MockAddon_Vanilla.toc` and add an entry that uses both library files. Add an XML fixture whose `file=` leaves the folder.

## 2. Offline runner follows XML

- [x] 2.1 Make `tools/entry_runner.lua` `loadToc` run `H.tocFiles` with the addon's name and namespace under `pcall`.
- [x] 2.2 In `tests/test_entries.lua`: the library entry returns the expected values; the commented-out file did not load; the escaping XML path fails with that path before any addon file runs. Break the XML following once and see the first test fail, then restore it. Verify `luajit tests/test_entries.lua` passes.

## 3. Offline command accepts covers

- [x] 3.1 Add `--specs` to the `offline` parser in `tools/ct.py` and pass `plan_requirements(plan, a.plan, a.specs)` through `offline_plan` to `validate`.
- [x] 3.2 In `tools/test_ct.py`: a copy of the offline fixture plan with `covers:` passes with `--specs` pointing at a fixture specs folder, and exits 2 with the "covers needs" message without one. Break the pass-through once and see the first test fail, then restore it. Update the existing count assertion if the fixture gains steps.

## 4. Docs and full check

- [x] 4.1 Update `docs/authoring-plans.md` "Check addon code offline": XML lines in the TOC are followed with the same path rules, frame templates and inline scripts are not, `--specs` works for `offline`. Verify `make test` and `make check` pass.
- [x] 4.2 Check `git diff --stat` shows no file under `CheckThat/`, so no version bump.

## Workflow follow-up

- Archive without a version bump (tools only), then commit with "Closes #135".
- Tell the KeepThat side it can drop its local TOC and plan workaround.
