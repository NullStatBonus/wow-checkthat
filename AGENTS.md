# CheckThat

## Documentation

When player-visible behavior, a setting, or a command changes, update the supporting docs in the same change.

- Cover affected features, settings, commands, and “Good to know” limits in `README.md`. Keep the README short: one or two lines for each feature. Put how a feature behaves, with its debug log lines, in `docs/features.md`. Plan writing is in `docs/authoring-plans.md`, evidence collection in `docs/harvesting.md` and the skills in `docs/skills.md`.
- Update the CurseForge/Wago text in `docs/listing.md`. Update its summary when the headline behavior changes.
- Name only addons and tools CheckThat integrates with. `tools/test_ct.py` fails when the README or `docs/` names an unrelated one.
- Update `docs/test-plan.md` with the relevant manual checks. Keep section numbers unique and in order.
- Document every new setting in the README and include its value in the debug report.
- Check the report with `/ct log`.
- Record what a client or another addon provides in `docs/contracts.md` whenever a probe or source review measures it.
- `tests/test_readme.lua` checks the README command list.
- Keep `schema/test-plan.schema.json` and the plan format specs (`openspec/specs/test-plan-format/`) in step with `CheckThat/Model/Plan.lua` and `tools/ct.py`.

## Testing

- Cover each new behavior with an automated test. Temporarily break the behavior, verify the test fails for the expected reason, then restore the behavior and verify it passes.
- Run the focused test during implementation. Use `make test` for the full suite and `make check` for packaging and version checks.
- Keep manual checks short and few. Give each check one player action, then a `Check:` line that states the expected result in words a player understands. Put the log line or saved variable that proves it on a separate `Log:` line for the reviewer. Never ask the player to read or interpret a log line.
- Give only essential setup before the action, but name everything the check depends on.
- Verify the result from debug logs or saved variables wherever possible. Add missing evidence in the same change.
- Keep raw saved variables and debug output out of Git. Anonymize any fixture derived from them.
- Each module's tests live in `tests/test_<module>.lua` and run alone with `luajit tests/test_<module>.lua`. `tests/harness.lua` builds the fake client. It models protected frames, combat, state drivers and OnShow and OnHide; `test_combat` plays the combat paths through the real `/ct` handler. `test_smoke` loads every file the TOC lists, with the real Ace3 libraries, and `test_options` validates the settings tree with AceConfig's own validator.
- Python tools have tests in `tools/test_*.py` (run by `make test`).
- Reserve in-game checks for what unit tests cannot prove. Read the copied `/ct log` report or saved variables yourself. Ask for an on-screen observation only when neither captures the result.
- Read the player's copied saved variables in `../shared-addon-resources/saved` (or run `tools/ct.py collect`) before asking for more in-game steps.

## Conventions

- **Game calls live in `Core/Adapter.lua` only.** Every function the game provides is read there, guarded and in `pcall`, returning nil when missing. `Model/` has no game globals; it gets `Adapter.Env()`. Unknown data is nil, never 0 or false. One exception: `UI/` and `Debug/` build, anchor and style their own frames (`CreateFrame`, `UIParent`, frame methods). A guard cannot stand in for a missing frame. `tests/test_layers.lua` fails when `Model/`, `Options/` or `Core/` (outside the adapter) uses a game global.
- **Logic is plain Lua.** `Model/` runs under `luajit` with a fake environment.
- **No input automation.** Every protected action stays a real player click or keypress. The runner shows text to copy, a button the player clicks, and reads logs and state. Slash commands and macro bodies come from the allow list in `Model/Plan.lua` (`Plan.SLASH`); a plan cannot extend it. Imported data is never executed.
- **Every player-facing sentence is `L["The whole English sentence"]`.** No concatenation, no variable keys. `tests/test_locale.lua` enforces this. See `docs/localization.md`.
- **New files go in both TOC files in the same order** (`make check` fails otherwise). `Libs/` is loaded by `embeds.xml`.
- **Plan text is not Markdown.** Text a player sees in a plan uses native color codes (`|cffffd100text|r`), never backticks or `**`. Validation rejects Markdown. See `openspec/specs/test-plan-format/`.
- **No AI or tool names in game.** Player-facing text never names Claude or any other assistant. Say what the player does, such as "so the game saves the log".
- **Chat text** never contains a raw `|`; double it.
- Choose game API code paths by checking whether the function exists, never by the client's name (the client is told apart by interface number).
- Persistent visuals default to a pure black background, with a user-selectable opacity. Draw no fill, border, or texture at zero opacity. Keep text and icons dimmable and avoid bright fixed-position fills.
- For each new UI control or screen, check Blizzard UI source and popular addons for an established pattern. Use a standard control when available. If a custom control is necessary, keep the standard fallback where the custom control is unavailable.
- Follow `DESIGN.md` for settings pages, control sizes and help text.

## Backlog

- Track deferred work and future ideas as GitHub issues (`gh issue create`), not in repo files. When a change or review defers something, open the issue in the same session and name it in the change's `design.md` (Non-Goals) when there is one.
- Issue text describes the gap, the code involved and a possible approach; no personal names.
- Check open issues (`gh issue list`) before proposing new work.

## OpenSpec, Git, and releases

- Follow the matching workflow under `.claude/skills/`. The archive procedure is in `.claude/skills/openspec-archive-change/SKILL.md` (`/opsx:archive` in Claude Code).
- **Bump the version only when addon code changed.** Addon code is any file under `CheckThat/`, the folder `.pkgmeta` ships. A change that touches only tools, tests, skills, docs, README, `Makefile`, `openspec/` or CI leaves both TOC versions, `CHANGELOG.md` and the release tag alone. Archive it without a bump. Check `git diff --stat` for `CheckThat/` before you bump.
- When addon code changed, bump the version once per OpenSpec change when its specs are applied to `openspec/specs/` during sync or archive. If `/opsx:sync` already set the version, keep it at archive.
- Set the same `## Version:` in `CheckThat/CheckThat_Vanilla.toc` and `CheckThat/CheckThat_Camelot.toc`. These are the only files that hard-code the addon version.
- Before 1.0, bump minor for a new capability or player-visible feature and patch for a fix or modification to existing behavior. From 1.0 onward, follow semantic versioning. Breaking saved settings or data requires a major bump from 1.0 onward.
- Archive before committing, pushing, or opening a PR for the change. Keep the code, synced specs, archive, and (for addon code changes) the version bump and matching `## X.Y.Z` changelog section in the same commit. Name the new version in the commit message when there is one. A change still active in `openspec/changes/` is ineligible for commit.
- Write `CHANGELOG.md` at archive, only for a version bump. Order entries by `New:`, `Changed:`, `Fixed:`, and `Removed:`. Bold the main item. For each fix, say what players saw before. Write one short line per entry in ASD-STE100 Simplified Technical English. Use active voice, simple tenses, common words, one fact per sentence, and at most 20 words per sentence. Describe what players see. Put settings-page, debug-report, and implementation details in the README.
- Tag a release only when the TOC version changed. If the TOC version is the same as the last tag, do not tag, publish or release.
- To publish an addon release, tag the archive commit `vX.Y.Z`, matching the TOC version, and push the tag as described in `docs/publishing.md`.
