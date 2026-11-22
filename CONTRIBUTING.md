# Contributing

Thanks for helping. TestThat is a WoW Classic addon (Lua) that walks a tester through the in-game test plans of other addons and records evidence for review. It supports WoW Forever and Classic Era.

## Getting set up

1. Install LuaJIT and Python 3.
2. Set up and run the tests:

   ```
   python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
   make test     # build plan strings, Lua tests, Python tests
   make check    # TOC, embeds and version checks; CI and the release workflow run the same
   ```

3. In game, `/reload` after a change, and `/console scriptErrors 1` so errors show as popups.

## How changes are made

Behavior is specified in `openspec/specs/`. A change to behavior goes through an OpenSpec change under `openspec/changes/` (proposal, design, spec deltas, tasks), is implemented against its tasks, and is archived when done. Archiving applies the deltas to the main specs and bumps the version. Bug fixes that restore specified behavior can skip the proposal; add a test that fails without the fix.

## Code

- **Match the surrounding code**: naming, comment density and idiom. Keep changes small and focused.
- **Keep the game out of the logic.** `TestThat/Model/` is plain Lua with no client calls. All client API reads go through `TestThat/Core/Adapter.lua`, wrapped in `pcall`.
- **Never automate input.** See `AGENTS.md`.
- **Write tests** for every behavior change in `tests/` (one `test_<module>.lua` per module).
- **New files** go in both TOC files in the same order. `make check` fails if they differ.
- **Plain language.** Player-facing text has no internal terms. See `DESIGN.md` and `docs/localization.md`.

## Plans

Plans live in `plans/*.yaml` and follow `schema/test-plan.schema.json`. `tools/wtt.py validate` checks one; `make build` compiles them to import strings.

To draft a plan for a change, use the `wtt-test-plan` skill in `skills/wtt-test-plan/`. It asks about scope, addon, output path, locale, clients and logging, then drafts, validates and reviews the plan. Run `make install-skill` to copy it to `~/.claude/skills/` (set `SKILL_DIR` to use another folder). The install records this checkout, so the skill finds `tools/wtt.py` from any addon repository.

## Versions and releases

- Bump `## Version:` in **both** TOC files to the same value when a change's specs are applied. Before 1.0.0 a new capability or user-visible feature raises the minor number and a fix to existing behavior raises the patch number.
- Add a `## X.Y.Z` section to `CHANGELOG.md`.
- Releases are tagged `vX.Y.Z` on the commit that carries the bump; see `docs/publishing.md`. Maintainers publish.

## Commits and pull requests

- One logical change per commit. Subject line in the imperative, under about 70 characters; name the new version in a release commit.
- In the pull request, say what changed, why, and how you tested it. Include screenshots for anything on a settings page.
- Before you open it: the tests and checks pass, and you have not committed secrets, saved variables or screenshots.
- Be kind in reviews. Disagree about the change, not the person.

## License

By contributing you agree that your contribution is licensed under the project's license (see `LICENSE`).
