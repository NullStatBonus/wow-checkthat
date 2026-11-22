# Tasks

## 1. Skill

- [x] 1.1 Write `skills/wtt-test-plan/SKILL.md` with the interview, draft, validate and review workflow; verify each spec scenario maps to a numbered instruction.
- [x] 1.2 Write `skills/wtt-test-plan/reference.md` with the depth checklist and by-hand lint checks; verify it cites the format files and copies none of their rules.
- [x] 1.3 Add a worked example plan under the skill folder; verify `python3 tools/wtt.py validate` passes on it.

## 2. Example stays valid

- [x] 2.1 Add a test in `tools/test_*.py` that validates the example plan; break the plan, verify the test fails, restore it, verify it passes.

## 3. Install

- [x] 3.1 Add `make install-skill` to the Makefile; verify `tools/test_wtt.py` installs to a temporary `SKILL_DIR`, finds the skill files and a `.wtt-root` that points at `tools/wtt.py`.

## 4. Docs

- [x] 4.1 Mention the skill in `CONTRIBUTING.md`; verify `make test` passes (README command-list test).
- [x] 4.2 Verify `make check` passes.

## Workflow follow-up

- Sync specs, bump the version in both TOC files, write the `CHANGELOG.md` entry and archive with `/opsx:archive`.
