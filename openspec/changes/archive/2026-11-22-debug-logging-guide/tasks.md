# Tasks

## 1. Guide

- [x] 1.1 Write `docs/debug-logging.md` (pattern, line quality, assertion kinds, formats, examples, checklist). Verify the example lines match the sibling addon sources and the guide is linked from the README.
- [x] 1.2 Add the guide to `BUNDLE` in the Makefile and to the install test's file list. Verify `python3 tools/test_wtt.py` passes; remove it from `BUNDLE`, confirm the install test fails, restore.

## 2. Skill

- [x] 2.1 Add the no-debug-log branch, the read-the-guide step and the issue-offer wording to SKILL.md; add an evidence-quality section to `reference.md`. Add `docs/debug-logging.md` to the skill file-reference test. Verify the test passes.
- [x] 2.2 Run `make test` and `make check`; run `make install-skill` into a temp folder and confirm `wtt/docs/debug-logging.md` exists.

## Workflow follow-up

- Archive (version 0.3.3, CHANGELOG entry) before commit.
