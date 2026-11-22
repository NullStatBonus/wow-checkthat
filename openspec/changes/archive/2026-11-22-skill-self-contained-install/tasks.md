# Tasks

## 1. Bundle

- [x] 1.1 Extend `install-skill` to copy the bundle (mirrored layout) and write `VERSION` from the TOC. Test: installed bundle files equal the sources and `VERSION` matches the TOC; installed `wtt.py validate example.yaml` passes using the dev venv.
- [x] 1.2 Drop `.wtt-root`; update the existing install tests (no `.wtt-root`, no stray temp folders, inside-checkout refusal unchanged). Verify `python3 tools/test_wtt.py` passes.

## 2. Private Python

- [x] 2.1 Build `.venv` in the temp folder and `pip install -r requirements.txt`; add `SKILL_NO_VENV=1` to skip it for tests. Test: with an unreachable index the install fails, names the step, and leaves the earlier copy intact. Break the failure handling, confirm the test fails, restore.
- [x] 2.2 Manual check: run a real `make install-skill SKILL_DIR=<tmp>`, then move the checkout away and run `<tmp>/wtt-test-plan/.venv/bin/python <tmp>/wtt-test-plan/wtt/tools/wtt.py validate <tmp>/wtt-test-plan/example.yaml`. Expect `ok`.

## 3. Skill and docs

- [x] 3.1 Rewrite SKILL.md step 0 (bundle first, then checkout), the validate command, the output-path question and the version report; update `reference.md` and `test_skill_points_at_files_that_exist`. Verify the tests pass.
- [x] 3.2 Document install requirements (Python 3 with venv, network once, re-run to update) in README; update `docs/publishing.md` if it mentions the skill. Verify `make test` and `make check` pass.

## Workflow follow-up

- Archive (version bump, CHANGELOG), then close or update issue #18 with the bundle approach.
