# Design

## Context

Plugin facts, from the Claude Code documentation read on 2026-11-23:
- A plugin folder holds `.claude-plugin/plugin.json` (only `name` is required) and `skills/<name>/SKILL.md`. Everything else sits at the plugin root.
- A skill folder may hold other files. `${CLAUDE_SKILL_DIR}` names the skill's folder.
- Commands are merged into skills. A plugin skill runs as `/<plugin>:<skill>`. Bare names and aliases are not documented.
- An install copies the plugin into a cache. State written there is lost on update. `${CLAUDE_PLUGIN_DATA}` survives updates. A `SessionStart` hook can run a setup command. No Python dependency install is documented.
- `claude plugin validate <path>` checks a plugin. `claude --plugin-dir <path>` loads one for a session. An install from a repository or folder needs a `marketplace.json`.

`make install-skill` copies the skills and a bundle into the user's skills folder and builds a private Python there. #18 proposed locating a checkout through the env file; that env file exists (#16 is closed). `openspec/config.yaml` accepts `operations.apply.guidance` and `operations.archive.guidance`.

## Goals / Non-Goals

**Goals:**
- A plugin folder that carries both skills and the tools, with no CheckThat checkout.
- The skills are the commands.
- An optional offer at apply and archive.

**Non-Goals:**
- Publishing the plugin: a `marketplace.json`, a release asset or a repository that is its own marketplace. Whether one repository can be both is not documented. Tracked in #53.
- A setup hook that installs Python packages. It would change the user's machine at every session start.
- Harvest for any OS and environment (#31). It is independent: #18's env-file dependency (#16) is done.
- Editing the generated `.claude/skills/openspec-*` files. `openspec update` rewrites them.
- Bare `/ct-plan` aliases. The documented form is `/<plugin>:<skill>`. The user-level install already gives bare `/ct-test-plan` and `/ct-verify`.

## Decisions

1. **The plugin carries the same bundle as `make install-skill`**, in `skills/ct-test-plan/ct/`. `ct-verify` finds it at `../ct-test-plan/ct`, as it does after `make install-skill`. The skills' own lookup needs no change. Alternative from #18: locate a checkout through the env file. Rejected: every sibling repository would depend on a second checkout.
2. **No command files.** A command file would only restate "start the skill". The skills already run as slash commands.
3. **Python without an install step.** A plugin cannot count on a private Python. The skill uses the private Python beside it when one exists (`make install-skill`), else `python3` when it imports PyYAML and jsonschema, else it stops and prints `python3 -m venv <dir> && <dir>/bin/pip install -r <tools>/requirements.txt` and asks where to put the environment. This amends the requirement that the skill runs with the bundled Python.
4. **The offer is guidance, not a hook.** A line under `operations.apply` and `operations.archive` in `openspec/config.yaml` tells the agent to offer `/ct-test-plan` when the change alters player-visible behavior.
5. **The plugin is a build output.** `make build-plugin` writes `build/plugin/`, which Git ignores, so no copy of the tools is committed.

## Risks / Trade-offs

- [The plugin works only with `--plugin-dir` until it is published] → accepted; the follow-up issue covers a marketplace. `make install-skill` serves users until then.
- [Advisory guidance may be ignored] → accepted; the offer is optional by design.
- [Not proved: Claude Code loads the built plugin in a real session] → `claude plugin validate` checks the manifest and skills. A manual check in `docs/test-plan.md` loads it with `--plugin-dir`.
