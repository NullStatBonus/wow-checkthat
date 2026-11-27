## Why

Issue #251: AGENTS.md makes `tools/ct.py` commands and output a compatibility surface, but the JSON of `report`, `diff`, `trend`, `status`, `coverage` and `drift` carried no format number, and nothing said which of about twenty commands are promises at 1.0.

## What Changes

- `ct.JSON_FORMAT = 1`. Every `--format json` / `--json` output (`report`, `coverage`, `drift`, `diff`, `trend`, `status`) and the saved error-lines file in the evidence folder carry `"format": 1`. It rises only when a key changes meaning or goes.
- `ct.STABLE_COMMANDS` and `ct.MAINTAINER_COMMANDS`. `recordings` and `census` are maintainer tools; their help starts with "maintainer tool, output may change". `from-md`, `sv2json` and `drift` stay stable, as the shipped skills run them.
- `docs/tools-guide.md`: a "Stable commands" section.
- Tests: each JSON output has `format`; every command is in one list; the docs list equals the stable list; maintainer help says so.

## Capabilities

### Modified Capabilities
- `run-verification`: ct.py JSON carries a format number, and the docs name the stable commands.

## Impact

`tools/ct.py`, `tools/test_ct.py`, `docs/tools-guide.md`. Additive: a reader that ignores unknown keys reads the outputs as before. No addon code; no version bump.
