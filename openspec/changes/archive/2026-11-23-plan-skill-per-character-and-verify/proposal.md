# Proposal

## Why

The `ct-test-plan` skill asks its interview in topic blocks and shows the whole draft at once (#33). It drafts one plan per scope, so a check that needs several characters lands in a plan that one run cannot finish (#52). Nothing reads a finished run back against its plan (#34), and the installed bundle cannot decode saved variables. A run belongs to one character, so a cross-character check needs one plan per character and a read-back afterward.

## What Changes

- The skill asks one question per turn, in dependency order, with a recommended answer. It skips questions the scope already answers.
- The skill drafts and reviews one step at a time. Accept all stays an opt-in.
- By default every step has one player action and one expected result. A compound step needs the author's request and is labelled.
- The skill asks which characters a check involves, usually one and sometimes two. It supports as many as the check needs. It drafts one plan per character role, named `<name>.<role>.yaml`. Each preamble names every partner plan. A `reviewer` line names the partner files, the step IDs and the expected relationship. Each plan is validated and compiled. The skill tells the author the import order for each role.
- A new `ct-verify` skill reads a finished run against its plan. The full-result input is the saved run data (`collect`) or an `/ct export` string read with `import-results`. A pasted `/ct log` report counts as partial evidence. It binds each run to its plan by plan digest, joins plan sets by step ID, and reports the recorded verdict and the evidence assessment separately. It never edits a plan and never runs the game.
- `make install-skill` installs both skills and the files that `collect` needs (`tools/sv2json.lua`, `CheckThat/Model/Json.lua`).

## Capabilities

### New Capabilities
- `run-verification`: how `ct-verify` reads finished runs against their plans.

### Modified Capabilities
- `test-plan-authoring`: one question and one step at a time, simple steps by default, one plan per character role.

## Impact

- Files: `skills/ct-test-plan/`, new `skills/ct-verify/`, `Makefile`, `tools/test_ct.py`, `README.md`, `docs/test-plan.md`, `openspec/specs/`.
- No file under `CheckThat/` changes. No version bump, no changelog entry, no tag. No plan-format field is added: plan sets link by file name, preamble and reviewer text.
- Closes #33, #34 and #52. First real case: #48.
