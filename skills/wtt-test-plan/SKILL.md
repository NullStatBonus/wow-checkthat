---
name: wtt-test-plan
description: Develop a TestThat (WTT) in-game test plan for the current scope of work (branch, diff or session). Interviews the author, drafts plan YAML, validates it, and reviews coverage and evidence. Use when the user asks for a test plan, a WTT plan, or tests for a change to a WoW addon.
---

# Develop a WTT test plan

Turn a scope of work into a plan TestThat can run. Ask before you assume. Read the format files; do not copy their rules into the plan from memory.

## 0. Locate the tools

The TestThat root holds `tools/wtt.py`, `schema/test-plan.schema.json`, `docs/test-plan.md` and `openspec/specs/test-plan-format/spec.md`.

A path counts as the root only when all four files above exist under it.

1. Try the path in `.wtt-root` beside this file. `make install-skill` writes it. If it is stale (a file is missing), say so and go on.
2. Try two folders up from this file (the skill runs inside the checkout).
3. If neither is a root, ask: "Where is your TestThat checkout?" Do not draft until you have one. Do not use the working directory; it may belong to another addon. Call the root `$WTT`.
4. Read `$WTT/docs/test-plan.md`, the format spec and the schema. Read `reference.md` and `example.yaml` beside this file.

## 1. Interview

Ask in this order. Ask one topic at a time, say why it matters, and offer a recommended default. Never answer for the author. Required before drafting: scope, addon, output path, locale, depth, clients, log source.

1. **Scope.** "What is in scope: the current branch, a diff (which range), or this session?" Read it. List what changed and what could break. Show the list and ask the author to correct it. If an OpenSpec change exists, use its proposal, specs and tasks as the checklist.
2. **Addon.** Which addon does the plan test, and which slash prefix does it use? Check it is in `Plan.SLASH` in `$WTT/TestThat/Model/Plan.lua` and `SLASH` in `wtt.py`. If not, stop: a plan for that addon needs a TestThat change first. Say so.
3. **Output.** "Where should I write the plan?" Suggest `plans/` in the TestThat checkout. Accept any path. Ask for the file name. Suggest `<addon>.yaml`; add the locale for non-English plans (for example `<addon>.deDE.yaml`).
4. **Locale.** Which client locale will the plan run on? Write the plan for that locale only. Authors keep one plan per locale. Do not translate. Player-visible text in the plan uses the strings that locale shows.
5. **Depth.** Sample (a handful of steps) or release plan (full coverage)? What is the riskiest part of the scope? What must never break?
6. **Clients.** Which clients are in scope: `classic-era`, `forever-camelot`, or both? Which steps are for one client only?
7. **Evidence.** Align with the addon's own logging; do not require a TestThat-style log.
   - What is the debug-log SavedVariable name, its path inside it, and its format (`strings` or `entries`)? Check `LOGS` in `wtt.py` and the addon source first, then confirm with the author.
   - Which behaviors already write a log line? Read the addon source for the lines. Do not invent lines.
   - Which scope items write nothing? Those need a player check (see item 8).
8. **Human eye.** For each changed behavior with no log line: can the author accept a player check, or should the addon gain a log line? List suggestions and let the author accept them all or decide one by one. What needs combat, a protected action, or a second client?
9. **Reload and state.** Which steps need `/reload`? Which checks survive a reload and which are per attempt or per session? What setup and cleanup does each step need?
10. **Return path.** Remind the author the result comes back by `/wtt export`, then `/reload`, then `wtt.py collect` and `report`. The tool needs the WoW SavedVariables path; ask for it only if the author wants to harvest now. A local config file for paths is not available yet.

## 2. Draft

Write YAML to the chosen path. Follow `example.yaml` for shape and the schema for fields. The rules that decide the draft:

- Cover each changed requirement or scenario with at least one step. Add one regression step for the nearest unchanged behavior. Add negative cases, and combat cases when the scope touches them.
- One action and one expected result per step. Keep a sample to a handful of steps; a release plan can be longer.
- Prefer a required `log` assertion where the addon already logs the evidence. Use `diagnostic` only for extra context. Use `absent` for "must not appear". Pick `scope` on purpose: use `attempt` for evidence expected after the step opens (attempts survive `/reload`); use `session` only for a line an earlier step wrote.
- Where nothing is logged, use `verify: [player]` and an `expect` a player understands. Never ask the player to read a log line.
- Every slash command named in step text goes in that step's `action.commands`, and only from the addon's allow list plus `/reload`, `/reloadui` and `/console scriptErrors 0|1`. No `/script`, `/run` or `/dump`. The card shows four command lines, so keep a step to four.
- Text uses native color codes (`|cff99ccffcommand|r`), never Markdown. Sentences are short, active voice, one fact each.
- Tag steps with `clients` when they apply to one client. Add `setup`, `cleanup` and `reload` where the step needs them.
- Never put raw saved variables or real character names in the plan.

## 3. Validate

Run `python3 $WTT/tools/wtt.py validate <plan>`. Use `$WTT/.venv/bin/python` if the system Python lacks PyYAML and jsonschema. Report every problem with its step id and fix it. `validate` does not catch a slash command named in text but missing from `commands`; check that by hand.

## 4. Review

Show the author:
- Coverage: each scope item and the step(s) that cover it; gaps in bold.
- The checklist in `reference.md`, with each finding tied to a step id.

Then ask: "Accept all suggestions, or go through the plan step by step?" Step by step: show one step with its findings, apply only what the author accepts, and leave rejected steps as they are. Re-run `validate` after changes, then run `compile <plan> -o <file>.wtt` on the final plan.

## 5. Gaps

For every step that has no log evidence, offer to open an issue in the addon's repository: `gh issue create`, with the gap, the code involved and a possible log line. No personal names. Ask first; never open it unasked.

## Finish

Run `compile <plan> -o <file>.wtt` on the final validated plan if you have not since the last edit. Report: plan path, `.wtt` path, step count, validate result, open gaps, and the return path. Do not claim the plan was run.
