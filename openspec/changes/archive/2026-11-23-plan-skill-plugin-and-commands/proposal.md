# Proposal

## Why

Sibling addon repositories can already install the skills at user level with `make install-skill`, but that needs a CheckThat checkout, `make` and network access for a private Python (#18). Nothing offers a plan when a change alters player-visible behavior (#17). Claude Code merges commands into skills: a plugin skill is also a slash command, so the skills already are the commands.

## What Changes

- `make build-plugin` builds a Claude Code plugin folder, `build/plugin/`, that holds `ct-test-plan`, `ct-verify`, the plan tools with the files that `collect` needs, and the version stamp. The plugin is named `checkthat`, so its commands are `/checkthat:ct-test-plan` and `/checkthat:ct-verify`. A test runs `claude plugin validate` on it when the `claude` command exists.
- No separate command files. The skills are the commands (#17).
- The skills no longer require the private Python of `make install-skill`. In a plugin they use `python3` with PyYAML and jsonschema, and print the setup command when a package is missing.
- `/opsx:apply` and `/opsx:archive` offer `/ct-test-plan` when player-visible behavior changed. The offer comes from `operations` guidance in `openspec/config.yaml`, not from edits to the generated OpenSpec skills. A sibling repository adds the same lines to its own config.
- `make install-skill` stays as the user-level install.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-authoring`: plugin build, Python for plugin installs, the optional offer.

## Impact

- Files: `Makefile`, `tools/test_ct.py`, `skills/*/SKILL.md`, `README.md`, `docs/test-plan.md`, `docs/publishing.md`, `openspec/config.yaml`, `openspec/specs/`.
- No file under `CheckThat/` changes. No version bump, no changelog entry, no tag.
- Closes #17. Delivers the build half of #18. Publishing the plugin through a marketplace is a follow-up issue.
