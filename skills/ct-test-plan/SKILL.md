---
name: ct-test-plan
description: Develop a CheckThat (CT) in-game test plan for the current scope of work (branch, diff or session). Interviews the author, drafts plan YAML, validates it, and reviews coverage and evidence. Use when the user asks for a test plan, a CT plan, or tests for a change to a WoW addon.
---

# Develop a CT test plan

Turn a scope of work into a plan CheckThat can run. Ask before you assume. Read the format files; do not copy their rules into the plan from memory.

## 0. Locate the tools

The tools root holds `tools/ct.py`, `schema/test-plan.schema.json`, `docs/test-plan.md`, `openspec/specs/test-plan-format/spec.md` and `CheckThat/Model/Plan.lua`. A path counts as the root only when all five exist under it.

1. Try `ct/` beside this file. `make install-skill` puts it there with a private Python at `.venv/` beside this file. Call the root `$CT` and the Python `$PY` (`.venv/bin/python` beside this file). Read `$CT/VERSION` and tell the author which tools version you use.
2. Else try two folders up from this file (the skill runs inside the checkout). Call that root `$CT`; use `$CT/.venv/bin/python` as `$PY` if it exists, else `python3`.
3. If neither is a root, ask: "Where is your CheckThat checkout?" Say that `make install-skill` in it sets up the skill for use anywhere. Do not draft until you have a root. Do not use the working directory; it may belong to another addon.
4. Read `$CT/docs/test-plan.md`, the format spec and the schema. Read `reference.md` and `example.yaml` beside this file. Read `$CT/docs/debug-logging.md` before the evidence question; if it is missing, say so and go on.

## 1. Interview

Ask in this order. Ask one topic at a time, say why it matters, and offer a recommended default. Never answer for the author. Required before drafting: scope, addon, output path, locale, depth, clients, log source.

1. **Scope.** "What is in scope: the current branch, a diff (which range), or this session?" Read it. List what changed and what could break. Show the list and ask the author to correct it. If an OpenSpec change exists, use its proposal, specs and tasks as the checklist.
2. **Addon.** Which addon does the plan test, and which slash prefix does it use? Check it is in `Plan.SLASH` in `$CT/CheckThat/Model/Plan.lua` and `SLASH` in `ct.py`. If not, stop: a plan for that addon needs a CheckThat change first. Say so.
3. **Output.** "Where should I write the plan?" Suggest `plans/` in the repository you are working in. Accept any path. Ask for the file name. Suggest `<addon>.yaml`; add the locale for non-English plans (for example `<addon>.deDE.yaml`).
4. **Locale.** Which client locale will the plan run on? Write the plan for that locale only. Authors keep one plan per locale. Do not translate. Player-visible text in the plan uses the strings that locale shows.
5. **Depth.** Sample (a handful of steps) or release plan (full coverage)? What is the riskiest part of the scope? What must never break?
6. **Clients.** Which clients are in scope: `classic-era`, `forever-camelot`, or both? Which steps are for one client only?
7. **Evidence.** Align with the addon's own logging; do not require a CheckThat-style log.
   - What is the debug-log SavedVariable name, its path inside it, and its format (`strings` or `entries`)? Check `LOGS` in `ct.py` and the addon source first, then confirm with the author.
   - Which behaviors already write a log line? Read the addon source for the lines. Do not invent lines.
   - Which scope items write nothing? Those need a player check (see item 8).
   - If the addon has no debug log at all, say so once and recommend adding one. Point to `$CT/docs/debug-logging.md` for the pattern and what a good line looks like. Ask: add one now, or draft with player checks? Either way, draft player checks, never invent log lines, and mark each step that would become a log assertion once the log exists (`notes: Becomes a log assertion once <addon> logs <event>.`).
8. **Human eye.** For each changed behavior with no log line: can the author accept a player check, or should the addon gain a log line? List suggestions and let the author accept them all or decide one by one. What needs combat, a protected action, or a second client?
9. **Reload and state.** Which steps need `/reload`? Which checks survive a reload and which are per attempt or per session? What setup and cleanup does each step need?
10. **Return path.** Remind the author the result comes back by `/ct export`, then `/reload`, then `ct.py collect` and `report`. The tool needs the WoW SavedVariables path; ask for it only if the author wants to harvest now. A local config file for paths is not available yet.

## 2. Draft

Write YAML to the chosen path. Follow `example.yaml` for shape and the schema for fields. The rules that decide the draft:

- Cover each changed requirement or scenario with at least one step. Add one regression step for the nearest unchanged behavior. Add negative cases, and combat cases when the scope touches them.
- One action and one expected result per step. Keep a sample to a handful of steps; a release plan can be longer.
- Prefer a required `log` assertion where the addon already logs the evidence. Use `diagnostic` only for extra context. Use `absent` for "must not appear". Pick `scope` on purpose: use `attempt` for evidence expected after the step opens (attempts survive `/reload`); use `session` only for a line an earlier step wrote.
- Where nothing is logged, use `verify: [player]` and an `expect` a player understands. Never ask the player to read a log line.
- Mark a step `auto: true` only when its required assertions are unconditional log lines or state probes that settle the step alone, with `verify: [assertions]`, no required `absent` check and no `player`. CheckThat then records the result itself. A step that needs a human judgment ("it looks right") stays manual. Ask the author for a `timeout` (5 to 300 seconds) when a failed step should be recorded without a click. Tell them the timeout counts from when the step opens, so it must cover the player's own action time plus the result. At the timeout a contradicted check records fail and missing evidence records unverified, never fail. Use `kind: wait-event` for a step the player finishes by doing something in game. It is valid only on an auto step.
- Every slash command named in step text goes in that step's `action.commands`, and only from the addon's allow list plus `/reload`, `/reloadui` and `/console scriptErrors 0|1`. No `/script`, `/run` or `/dump`. The card shows four command lines, so keep a step to four.
- Text uses native color codes (`|cff99ccffcommand|r`), never Markdown. Sentences are short, active voice, one fact each.
- Tag steps with `clients` when they apply to one client. Add `setup`, `cleanup` and `reload` where the step needs them.
- Never put raw saved variables or real character names in the plan.

## 3. Validate

Run `$PY $CT/tools/ct.py validate <plan>`. Report every problem with its step id and fix it. `validate` warns (without failing) about a slash command named in text but missing from `commands`; fix each warning.

## 4. Review

Show the author:
- Coverage: each scope item and the step(s) that cover it; gaps in bold.
- The checklist in `reference.md`, with each finding tied to a step id.

Then ask: "Accept all suggestions, or go through the plan step by step?" Step by step: show one step with its findings, apply only what the author accepts, and leave rejected steps as they are. Re-run `validate` after changes, then run `compile <plan> -o <file>.ct` on the final plan.

## 5. Gaps

For every step that has no log evidence, offer to open an issue in the addon's repository: `gh issue create`, with the gap, the code involved and a possible log line. If the addon has no debug log, offer one issue for the log facility (the pattern in `$CT/docs/debug-logging.md`) plus one issue per needed line, each naming the steps it unlocks. No personal names. Ask first; never open it unasked.

## Finish

Run `compile <plan> -o <file>.ct` on the final validated plan if you have not since the last edit. Report: plan path, `.ct` path, step count, validate result, open gaps, and the return path. Do not claim the plan was run.
