# Tasks

## 1. Rename

- [ ] 1.1 Move the files: `tools/wtt.py` to `tools/ct.py`, `tools/test_wtt.py` to `tools/test_ct.py`, `skills/wtt-test-plan` to `skills/ct-test-plan`. Replace `wtt` with `ct` and `WTT` with `CT` in every tracked text file outside the archive, the vendored libraries, `CHANGELOG.md` history and `openspec/specs`. Verify with `git ls-files | xargs rg -i wtt` showing only allowed history, and `make test` passing.
- [ ] 1.2 Check the places a mechanical replace can miss: the `Makefile` skill and bundle paths, the skill's marker file and install folder, `.gitignore`, the schema's `ct` property, the macro names. Verify with `make test`, `make check` and `make -n install-skill` naming the new paths.
- [ ] 1.3 Update the comments in the parent folder's `Copy-CheckThatEvidence.bat` that name `tools/wtt.py`. Verify by reading the file.

## 2. Guard

- [ ] 2.1 Add a test to `tools/test_ct.py` that lists tracked files with `git ls-files` and fails if any text file outside the archive, the vendored libraries and `CHANGELOG.md` contains `wtt`, `WTT` or `TestThat`. Verify it fails on a planted `wtt` and passes after.

## 3. Docs and integration

- [ ] 3.1 Re-read the README, `docs/` and the skill for sentences the rename made awkward. Add no explanation of the old name.
- [ ] 3.2 Run `make test` and `make check`; fix failures. Verify both exit 0.
- [ ] 3.3 In game: import `build/selftest.ct` and run the self-test. Check the Run button step and the reload step settle, and `/ct log` lines start with `[ct]`.

## Workflow follow-up

- At archive: sync the deltas, bump both TOC versions to 0.5.2, add the matching `CHANGELOG.md` section and name the version in the commit message.
- After the PR merges: tag `v0.5.2` only after the in-game check.
