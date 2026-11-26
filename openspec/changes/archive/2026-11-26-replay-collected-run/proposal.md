## Why

After a run fails, the quickest proof that a revised check is right is to judge it against the log the game wrote. Today `ct replay --sv <dir>` needs a hand-made fixture folder: the author finds the right `evidence/sv/*.lua` copies (the character file for the addon log and the account file for CheckThat), copies and renames them. In a ClosestVendor run that replay caught two checks whose expected line order was wrong in the real addon, which `replay-flow` cannot catch because it writes the lines itself (#223). Separately, `ct report` warns about a run of another addon build only when the author types `--expect-version`; left out, an old build reads as a test of the current code (#226).

## What Changes

- `ct.py replay <plan> --run <run id> [--dest evidence]` picks the saved-variable copies the run's newest revision was collected with and judges the plan's log and fact checks against them, as `--sv` does. `--sv` stays and works as before; one of the two is required.
- The copies are the CheckThat account file that holds the run at its newest revision, plus the addon files of the same client and account, account-wide and from the run's own character folder, each taken from the same collect as that CheckThat copy. The command prints which files it used.
- `ct.py report` takes `--addon-src <folder>`. With it, or with `--plan <file>` whose `offline.toc` exists under the addons folder, `--expect-version` defaults to the TOC's `## Version:` and the output says where the version came from. An explicit `--expect-version` still wins.
- The `ct-test-plan` skill's "Revise after a run" replays the revised plan against the failing run before it asks for another in-game run, and passes `--addon-src` to `report`. The `ct-verify` skill passes `--addon-src` too.

## Capabilities

### New Capabilities

### Modified Capabilities

- `plan-replay`: replay judges a plan against a collected run's saved variables.
- `run-verification`: the report's expected version defaults to the addon's TOC version.
- `test-plan-authoring`: revise mode replays the revised plan against the failing run.

## Impact

Tools, skills and docs only: `tools/ct.py`, `tools/test_ct.py`, `skills/ct-test-plan/SKILL.md`, `skills/ct-verify/SKILL.md`, `docs/authoring-plans.md`, `docs/skills.md`, `openspec/specs/`. No file under `CheckThat/` changes, so no version bump. `replay --sv` and `report` without the new options behave as before.
