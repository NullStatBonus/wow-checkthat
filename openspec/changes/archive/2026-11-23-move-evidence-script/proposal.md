# Proposal

## Why

The 0.8.0 package holds `CheckThat/Copy-CheckThatEvidence.bat`. The packager ships every repository file at the top level that `.pkgmeta` does not ignore. A Windows script does not belong in the game's addon folder.

## What Changes

- Move `Copy-CheckThatEvidence.bat` into `tools/`, which `.pkgmeta` ignores. It still runs the script beside it and writes `evidence-src` in the repository folder.
- A test fails when a script file sits at the top of the repository.
- Release 0.8.1.

## Capabilities

### New Capabilities

### Modified Capabilities

## Impact

- Files: `tools/Copy-CheckThatEvidence.bat`, `README.md`, `docs/test-plan.md`, `tools/test_ct.py`, both TOCs, `CHANGELOG.md`.
- The package changes, so the version rises to 0.8.1 although no Lua file changes.
