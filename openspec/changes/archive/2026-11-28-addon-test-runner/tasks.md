# Tasks

## 1. Runner

- [x] 1.1 `Runner.run` takes `opts.hooks` (a table) and `opts.hooksFile` (for the nil-read skip); a plan block still loads hooks only from its file
- [x] 1.2 Move the reload step into a function and add `ctx.reload`, `ctx.ok` and `ctx.raises`
- [x] 1.3 `tools/addon_test.lua`: load a test file with `ct`, run each test through `Runner.run`, print JSON
- [x] 1.4 Lua tests in `tests/test_entries.lua` and a fixture addon test file; break each behavior and see the test fail

## 2. ct test

- [x] 2.1 `ct test [folder] --client --name --recordings`: TOC per client, one process per file and client, lines, nil-read report, summary, exit codes
- [x] 2.2 Python tests in `tools/test_ct.py`; break each behavior and see the test fail
- [x] 2.3 Add `tools/addon_test.lua` and `docs/addon-tests.md` to the bundle

## 3. Docs

- [x] 3.1 `docs/addon-tests.md` with a worked example; `ctx` table in `docs/authoring-plans.md`; stable list in `docs/tools-guide.md`; `docs/skills.md`; plan skill
- [x] 3.2 Run the docs example in a scratch addon through the installed layout
- [x] 3.3 `--tests DIR` for repos that keep tests outside the shipped folder: test in `tools/test_ct.py`, `docs/addon-tests.md`, spec scenario
