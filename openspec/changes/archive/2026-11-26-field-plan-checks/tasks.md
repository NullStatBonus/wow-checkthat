# Tasks

## 1. Version step behind the TOC (#221)

- [x] 1.1 `toc_version(path)` and `version_lag_warning(plan, toc)` in `tools/ct.py`; `validate` and `compile` take `--addon-src` and fall back to `offline.toc` under `default_addons()`. Verify: tests for ge behind, ge equal, eq different, string value, no TOC, `offline.toc` fallback, and the CLI printing the warning with exit zero; break the comparison and see the test fail

## 2. Step references in player text (#222)

- [x] 2.1 `reference_warnings(plan)` in `tools/ct.py`, printed by `print_warnings`: `check N.M`, `step N.M` and the plan's own dotted step ids in action text, `setup` and `expect`; not `notes` or `reviewer`. Verify: tests for each pattern and field, the reviewer exemption, and every plan under `plans/` and `skills/` (fix or list any that warn); break the field list and see the test fail

## 3. Format strings in ct lines (#224)

- [x] 3.1 Format-string match in `lines_check`: quoted strings with a conversion become tokens; substring automaton with an 8-literal-character floor. Verify: tests for `trigger go sell (bags=`, `%%`, `%5.2f`, a placeholders-only string that must not match, and the existing LinesCheck tests; break the floor and see the test fail

## 4. Skill, docs and check

- [x] 4.1 `skills/ct-test-plan/SKILL.md` and `reference.md`: refer to earlier steps by what the player did; `validate --addon-src`; the new warnings in the Validate section. `docs/authoring-plans.md`: the validate step names both warnings and `--addon-src`; the `ct lines` text names format strings. Verify: skill text test, `make test` (flag lint covers `--addon-src`)
- [x] 4.2 Open an issue for `ct report --expect-version` defaulting to the TOC version, and name it in design.md Non-Goals. Verify: issue exists
- [x] 4.3 `make test` and `make check` pass; no file under `CheckThat/` changes

## Workflow follow-up

- Archive with `/opsx:archive` (no version bump: no addon code). Commit with the synced specs and archive, naming #221, #222 and #224.
