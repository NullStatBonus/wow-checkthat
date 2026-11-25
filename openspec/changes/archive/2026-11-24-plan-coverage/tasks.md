# Tasks

## 1. Field

- [x] 1.1 Add `covers` to the schema (step and section). Verify `tools/test_ct.py`: a known name validates; an unknown name and a missing specs folder are errors.
- [x] 1.2 Strip `covers` in `merge_sections`. Verify the compiled string is byte-identical with and without it, also with cases.
- [x] 1.3 Game ignores unknown fields. Verify `tests/test_plan.lua`.

## 2. Report

- [x] 2.1 Extractors and `ct.py coverage`. Verify against the fixture addon: three subcommands, two used, one unused; a setting used only by a fact check counts as covered; a requirement report.
- [x] 2.2 `--evidence`. Verify passed, failed or unverified, and never run.

## 3. Docs and release

- [x] 3.1 README, `docs/authoring-plans.md`, `docs/harvesting.md`, `docs/skills.md`, skill.
- [x] 3.2 `make test` and `make check` pass. No addon code changed: no version bump.
