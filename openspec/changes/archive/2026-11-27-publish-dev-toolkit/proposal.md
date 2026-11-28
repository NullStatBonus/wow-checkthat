## Why

An addon developer can use the plan tools, the skills and the fake client only after cloning CheckThat and running `make install-skill`. The Claude Code plugin is built but never published (#53). A developer with another agent has no package at all. A missing LuaJIT shows up only as a bare error from the command that needed it. To make CheckThat a complete toolkit for developers who build and test addons, installing it must come first, with no checkout.

## What Changes

- Each release publishes the Claude Code plugin through a marketplace in this repository. A root `.claude-plugin/marketplace.json` names a `plugin` branch, and the release workflow commits the built plugin there. Developers install it with `claude plugin marketplace add NullStatBonus/wow-checkthat` and `/plugin install`.
- Each release attaches an agent-neutral toolkit zip to the GitHub release. It holds the `ct-test-plan` and `ct-verify` skill folders with the bundle, the same layout `make install-skill` writes, without a private Python. A developer unzips it into any agent's skills folder.
- A new `make build-toolkit` builds that zip. `make install-skill`, `make build-plugin` and `make build-toolkit` share one bundle step, so the three outputs cannot drift.
- A new `ct setup` command creates a per-user Python environment with the tools' requirements, outside the plugin cache so an update keeps it. The launcher and the skills look for it after the private Python that `make install-skill` creates.
- `ct doctor` adds a tools section: the tools version, the Python packages, and whether `luajit` is on the path, with the install command for the platform. Its exit code keeps its meaning.
- A command that needs LuaJIT and cannot find it names the install command for the platform and `ct doctor`.
- A manual `workflow_dispatch` run builds and validates the plugin and the zip without publishing them, so the pipeline can be checked before the next tag.
- The docs lead with the marketplace and zip installs and keep `make install-skill` as the checkout install. They state that the bundle's `tests/` files are internal and not a contract (#273).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `test-plan-authoring`: the plugin is published through a marketplace, a toolkit zip is published, the bundle comes from one shared step, `ct setup` creates the private Python, `ct doctor` reports the tool prerequisites, and a missing LuaJIT names its install.

## Impact

- `Makefile` (`install-skill`, `build-plugin`, new `build-toolkit`, shared bundle step), `.github/workflows/release.yml` (plugin branch, toolkit asset, dispatch dry run), a new root `.claude-plugin/marketplace.json`, `.pkgmeta` (ignore the new folder).
- `tools/ct.py`: new `setup` command, a `doctor` tools section, the LuaJIT hint in `run_luajit`. `tools/test_ct.py` covers each.
- `skills/ct-test-plan/SKILL.md` and `skills/ct-verify/SKILL.md`: name `ct setup` where they now print the venv commands.
- Docs: `docs/skills.md`, `docs/adopting.md`, `docs/setup.md`, `docs/publishing.md`, `docs/tools-guide.md` (`setup` joins the stable list), `README.md`, `docs/listing.md` (developer section).
- No addon code under `CheckThat/` changes, so there is no version bump. The first publish happens at the next tag, which the maintainer decides.
