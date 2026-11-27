## 1. Addon

- [x] 1.1 `Model/Pattern.lua`: the Lua 5.1 matcher in plain Lua with a step budget (a set item costs a step), a hybrid with plain search and native `string.find` for simple patterns, a per-evaluation allowance and a two-generation cache; in both TOC files
- [x] 1.2 `Plan.PatternProblem`: refuse only a pattern `string.find` raises on, and one over 200 characters
- [x] 1.3 `Plan.Validate`: pattern check for log, sequence and `matches`; type checks for the crash sites
- [x] 1.4 `Evidence`: run every plan pattern with `Pattern.Find`; a line over the budget is unchecked; never run an unreadable pattern; `ReadLog` guard
- [x] 1.5 Lua tests: differential test of the matcher against `string.find`, budget, cache, verdicts, old patterns, types, import regression (break each, watch it fail, restore)

## 2. Tools

- [x] 2.1 `pattern_problem` and `check_matcher` in `ct.py`; `validate` refuses null with its path
- [x] 2.2 Schema: typed `value`, non-empty title, expect, action text, fact addon and key, pattern description
- [x] 2.3 `ct.py compile` refuses a string over `MAX_ENCODED`
- [x] 2.4 `tools/replay_sv.lua` loads `Plan.lua` and `Pattern.lua`
- [x] 2.5 Parity cases in `tests/fixtures/parity-bad.json`, `tests/fixtures/parity-patterns.json`; Python tests and a generated differential test against Lua

## 3. Docs

- [x] 3.1 `docs/features.md`, `docs/authoring-plans.md`, `docs/test-plan.md`, skill text
- [x] 3.2 `CHANGELOG.md` 0.21.0
- [x] 3.3 `make test` and `make check`
