# Tasks

- [x] 1.1 Pure-Python reader and `sv_json` on it. Verify: `tools/test_ct.py` compares it with luajit on every fixture; break an escape rule and see it fail.
- [x] 1.2 `collect --plan`, source report, missing-global warning, PowerShell `-Names`. Verify: a plan naming a made-up addon collects its file from a fake WTF tree; break the lookup and see it fail.
- [x] 1.3 `--shot-slack`. Verify: slack 0 makes an edge screenshot loose.
- [x] 1.4 Docs: README, `docs/harvesting.md`, `docs/skills.md`.
- [x] 1.5 Comment on #95.

## Workflow follow-up

- No version bump, changelog entry or tag: no file under `CheckThat/` changes.
