## Context

The plan tools, the two skills and the fake client ship as one bundle (`BUNDLE` and `BUNDLE_DIR` in the `Makefile`). There are two ways to get it today, and both need a CheckThat checkout:

- `make install-skill` copies `skills/ct-test-plan` and `skills/ct-verify` into a skills folder, copies the bundle to `ct-test-plan/ct/`, stamps `VERSION` and creates `ct-test-plan/.venv`. It refuses a target inside the checkout.
- `make build-plugin` copies the same skills as `plan` and `verify` into `build/plugin/` and the same bundle to `skills/plan/ct/`, and writes `plugin.json`. Nothing publishes it (#53).

The two recipes repeat the copy loop. `.github/workflows/release.yml` runs on a `v*` tag only: test, package, upload, GitHub release. `ct.py report` already warns when a run's `writerVersion` differs from the bundle's `VERSION`, so stale-bundle detection without a checkout already exists and is not part of this change.

What the Claude Code docs measured (code.claude.com plugin pages, read 2026-11-27):

- `marketplace.json` sits at `.claude-plugin/marketplace.json` and needs `name`, `owner.name` and `plugins[]`. A plugin source may be `{"source": "github", "repo": "owner/repo", "ref": "<branch>"}`.
- `claude plugin validate <dir>` validates the marketplace when one is present, else `plugin.json`. It does not fetch sources. The docs do not say whether it needs a sign-in.
- An installed plugin is copied to `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, one folder per version. A file written into it does not survive an update. `plugin.json` `version` drives update detection.
- `${CLAUDE_PLUGIN_DATA}` persists, but only hooks, MCP and LSP servers get it, not a skill's shell commands.

## Goals / Non-Goals

**Goals:**

- A developer with no checkout installs the toolkit in one step from the marketplace or from a release zip.
- The installed tools reach a working Python and say how to get LuaJIT.
- The three outputs cannot drift, and the pipeline can be checked before the next tag.

**Non-Goals:**

- Bundling LuaJIT binaries. Detect it and name the install instead: a binary for each platform is a build and update burden.
- A public fake-client API for an addon's own tests (#273). This change only states that `tests/` in the bundle is internal.
- Self-service recordings and an open mock list (#214).
- Publishing to a marketplace outside this repository.
- Tagging a release. The maintainer chooses the next tag, and the toolkit does not need one.

## Decisions

**Marketplace on `main`, plugin on a `plugin` branch.** `build/` is gitignored, so `main` cannot hold the built plugin. The root `.claude-plugin/marketplace.json` names `checkthat` with `{"source": "github", "repo": "NullStatBonus/wow-checkthat", "ref": "plugin"}`. The release job builds into a worktree of `plugin`, commits with the message `checkthat <version>` and pushes. It never force-pushes, so an earlier version's commit stays reachable. Alternative: hold the marketplace and the plugin on the `plugin` branch with a `./` relative source, installed as `owner/repo#plugin`. That form is the documented one for a plugin in the marketplace repository, but its install command is longer and it hides the marketplace from `main`. Keep it as the fallback if the `github` ref form fails the first real install.

**Publishing does not wait for a tag.** A tools-only change never bumps the addon version, so it never gets a tag. A manual run of the release workflow on `main` with `publish` set commits the plugin to the `plugin` branch and replaces the toolkit zip on the release of the current version (`gh release upload --clobber`). It creates no tag and no release and does not touch CurseForge or Wago. A tag release publishes both as well, so an addon release never ships stale tools.

**Plugin version is the addon version plus the commit** (`1.0.0+3f9c2a1b7d4e`). Claude Code updates an installed plugin only when `plugin.json` `version` changes. A plain `1.0.0` would hide every tools-only publish. A separate tools version would need its own bump rules and changelog. The `+commit` suffix (semver build metadata) still names the CheckThat version the tools match, and it changes on every publish. Alternative: leave `version` out so Claude Code uses the commit. Rejected: the user would see no version at all. The bundle's `VERSION` stays the plain addon version, because the run-version warnings compare it with a run's `writerVersion`.

**Toolkit zip has the install-skill layout without a venv.** `build/CheckThat-toolkit-<version>.zip` holds `ct-test-plan/` and `ct-verify/`, as `make install-skill SKILL_NO_VENV=1` writes them, so `ct-verify`'s `../ct-test-plan/ct` lookup works unchanged. The format is zip, because Windows extracts it natively. Python's `zipfile` writes it and keeps the mode bits. `unzip` restores them. Where an extractor drops them, `sh ct-test-plan/ct/tools/ct` still works, and the docs say so. It is uploaded with the existing `gh release create`, next to the addon zip, under a name the packager cannot produce.

**One bundle step: `tools/bundle.sh <dest-ct-dir>`.** It copies `BUNDLE` and `BUNDLE_DIR` (passed from the Makefile) and writes `VERSION`. `install-skill`, `build-plugin` and `build-toolkit` call it. `build-toolkit` builds into `build/toolkit/`, which is inside the checkout. That is allowed: the "outside the checkout" guard stays on `install-skill`, where it protects a user's skills folder.

**Per-user Python from `ct setup`.** The environment goes in `$XDG_DATA_HOME/checkthat/venv` (default `~/.local/share/checkthat/venv`), and `%LOCALAPPDATA%\checkthat\venv` on Windows, outside the plugin cache, so an update does not wipe it. `ct setup` builds into a temporary sibling folder and renames it into place only after `pip` succeeds. The `tools/ct` launcher and the SKILL.md Python lookup add this path between the private Python and `python3`. `ct setup` is written in the standard library only, because it runs before PyYAML exists. It runs from `python3` through the launcher, and the launcher still reaches `ct.py` with no packages. Alternative: a plugin hook that installs into `${CLAUDE_PLUGIN_DATA}`. Rejected: it covers the plugin only, not the zip, and a skill's shell cannot see that variable.

**`ct doctor` tools section.** It adds lines and does not change the exit code, which stays the saved-variables answer, as the stable-command rule requires. It prints the install command for the platform: `brew install luajit` on macOS, `sudo apt install luajit` on Debian or Ubuntu (with a general "your package manager" line for other Linux), and `scoop install luajit` on Windows. These commands are a hint, not a measured contract.

**LuaJIT hint in `run_luajit`.** The `ValueError` text keeps its current start and adds the platform command and `ct doctor`, so an existing reader that matches the start keeps working.

**Dry run.** `release.yml` gains `workflow_dispatch` with a `publish` input (default off). On a dispatch it runs the tests, `make build-plugin`, `make build-toolkit` and `claude plugin validate` (installed with `npm install -g @anthropic-ai/claude-code`) on the built plugin and on the repository root (the marketplace). Then it uploads both as workflow artifacts. The packager and a new GitHub release run only for a tag. The `plugin` branch push and the zip replacement run for a tag or for a dispatch on `main` with `publish` set. The dispatch run also answers the open question of whether `validate` needs a sign-in.

## Risks / Trade-offs

- [The `github` same-repo `ref` form is schema-valid but not the documented pattern] -> The first publish is followed by a real install check (tasks). The fallback layout is designed above.
- [`claude plugin validate` may need a sign-in in CI] -> The dispatch run finds out before a tag. If it does, the release gate falls back to `claude plugin validate` in `make test` on a maintainer machine, and the gap is filed as an issue.
- [`.claude-plugin/` is a new top-level folder] -> Add it to `.pkgmeta` `ignore`, as `tools/test_ct.py` requires.
- [A per-user environment shared by every installed version] -> `requirements.txt` changes rarely. `ct doctor` names a missing package, and `ct setup` again fixes it.
- [The `plugin` branch grows by one commit for each release] -> That is small, and it keeps earlier versions installable by SHA.

## Migration Plan

All additive. `make install-skill` keeps its layout and private Python, which the lookup order still prefers. The first publish is a manual run with `publish` set after merge, against the existing `v1.0.0` release. Rollback: delete `marketplace.json` from `main`, and the `plugin` branch stops being advertised.

## Open Questions

- Whether `claude plugin validate` runs in CI without a sign-in. The dispatch dry run answers it.
