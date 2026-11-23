# Tasks

## 1. Plugin (#18)

- [x] 1.1 Add `make build-plugin`: `build/plugin/.claude-plugin/plugin.json` (name `checkthat`, the addon version, MIT), both skills, the bundle under `skills/ct-test-plan/ct/` and the version stamp. Verify: a test in `tools/test_ct.py` builds it and checks the manifest, both skills, the tools, the Lua decoder files and the version stamp, and runs `claude plugin validate` on it when `claude` exists.
- [x] 1.2 Update step 0 of both skills for a plugin install: private Python beside the skill, else `python3` with PyYAML and jsonschema, else the printed setup command. Verify: a test fails when either skill lacks the fallback text; a dry run with no PyYAML stops with the command.
- [x] 1.3 Run `collect` from the built plugin on the verify fixture. Verify: a test copies `build/plugin` elsewhere and decodes a run from a sibling directory.

## 2. Offer (#17)

- [x] 2.1 Add the optional offer under `operations.apply` and `operations.archive` in `openspec/config.yaml`. Verify: `openspec instructions apply --change <name> --json` and `openspec instructions archive --change <name> --json` return the guidance.

## 3. Docs and close out

- [x] 3.1 Update `README.md` (plugin build and `--plugin-dir` use, apart from the in-game `/ct` list), `docs/test-plan.md` (load the built plugin and run both commands) and `docs/publishing.md`. Verify: `make test` and `make check`.
- [x] 3.2 Open an issue for publishing the plugin through a marketplace, name it in `design.md` Non-Goals, and comment on #18 and #17. Check open issues first.

## Workflow follow-up

- No version bump, changelog entry or tag: no file under `CheckThat/` changes.
