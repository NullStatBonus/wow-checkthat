## Why

A ClosestVendor 1.13.1 run showed three gaps in the plan tools. The version step accepted 1.13.0 after the TOC moved to 1.13.1, so the tester ran the old build and the fix was never in game, yet the step passed (#221). Player text said "the vendor you opened in check 1.3", but the card shows titles, not ids, so the tester opened the wrong window and failed the step twice (#222). `ct lines` reported lines built with `format` as not found whenever the asserted text spans a placeholder, so every run listed the same noise and a real miss looked the same (#224).

## What Changes

- `ct.py validate` and `compile` take `--addon-src <folder>`. With it, or with the plan's `offline.toc` found under the addons folder, they read `## Version:` from the addon's TOC and warn when the first step's version fact accepts an older build: `cv.s0.1 accepts 1.13.0; the addon is 1.13.1`.
- `ct.py validate` warns when a step's action text, `setup` or `expect` cites a step number the card does not show (`check 1.3`, `step 1.3`, or one of the plan's own step ids). `notes` and `reviewer` stay free, because only the reviewer reads them.
- `ct.py lines` matches an asserted line against the addon's format strings with each placeholder (`%s`, `%d`, ...) treated as any text, so `trigger go sell (bags=` matches `"trigger %s%s%s (bags=%s"`.
- The `ct-test-plan` skill refers to an earlier step by what the player did, never by number, and passes `--addon-src` to `validate`.

## Capabilities

### New Capabilities

### Modified Capabilities

- `test-plan-format`: validation warns about a version step older than the addon's TOC, and about step references in player text.
- `plan-replay`: `ct lines` matches lines built from format strings.
- `test-plan-authoring`: the skill never cites a step number in player text and validates with the addon source.

## Impact

Tools, skill and docs only: `tools/ct.py`, `tools/test_ct.py`, `skills/ct-test-plan/`, `docs/authoring-plans.md`, `openspec/specs/`. No file under `CheckThat/` changes, so no version bump. All new output is warnings: exit codes and the compiled string are unchanged.
