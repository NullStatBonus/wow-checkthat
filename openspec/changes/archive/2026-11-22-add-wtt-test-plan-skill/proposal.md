# Proposal

## Why

Plans are written by hand or converted from Markdown. Nothing guides an author from a scope of work to a plan that TestThat can run. The format rules, the slash allow list and the evidence model sit in several files, so new plans often miss commands, assertions or client tags (issue 15).

## What Changes

- Add an agent skill, `wtt-test-plan`, in `skills/wtt-test-plan/`. It interviews the author, drafts a plan YAML, validates it, and reviews it against a checklist.
- The skill asks for the scope source (current branch, a diff, or the session), the target addon, the output path (default `plans/`), the locale, depth, clients and evidence.
- The skill aligns evidence with the target addon's own debug log. It never assumes TestThat's log shape.
- The author accepts suggestions in bulk or walks the plan step by step.
- The skill finds `tools/wtt.py`, `schema/` and `docs/test-plan.md` from a checkout path recorded at install, else relative to itself, and asks for a path when it cannot.
- Add `make install-skill`, which copies the skill to the user's skills folder and records the checkout path.
- The skill points to the format files and does not copy their rules.
- Add a short `reference.md` (depth checklist) and one worked example plan.
- Document the skill in `CONTRIBUTING.md`. The README, listing and `docs/test-plan.md` cover player-visible behavior, so they stay unchanged.

## Capabilities

### New Capabilities

- `test-plan-authoring`: how the skill gathers scope, asks questions, drafts, validates and reviews a plan.

### Modified Capabilities

None.

## Impact

- New: `skills/wtt-test-plan/SKILL.md`, `reference.md`, an example plan.
- `Makefile`: new `install-skill` target.
- Docs: `CONTRIBUTING.md`.
- No change to the addon, `tools/wtt.py` or the schema.
- Deferred, tracked as issues: lint (#12), local ENV file for paths (#16), `/wtt-plan` command and OpenSpec hook (#17), shared plugin (#18).
