---
name: ct-test-plan
description: Develop a CheckThat (CT) in-game test plan for the current scope of work (branch, diff or session). Interviews the author, drafts plan YAML, validates it, and reviews coverage and evidence. Use when the user asks for a test plan, a CT plan, or tests for a change to a WoW addon.
---

# Develop a CT test plan

Turn a scope of work into a plan CheckThat can run. Ask before you assume. Read the format files; do not copy their rules into the plan from memory.

## 0. Locate the tools

The tools root holds `tools/ct.py`, `schema/test-plan.schema.json`, `docs/test-plan.md`, `openspec/specs/test-plan-format/spec.md` and `CheckThat/Model/Plan.lua`. A path counts as the root only when all five exist under it.

1. Try `ct/` beside this file. `make install-skill` puts it there with a private Python at `.venv/` beside this file. Call the root `$CT`. Set `$PY` to `.venv/bin/python` beside this file when it exists (`make install-skill`). In a plugin install there is none: use `python3` when `python3 -c "import yaml, jsonschema"` succeeds. If it fails, stop and tell the author to run `python3 -m venv <dir> && <dir>/bin/pip install -r $CT/requirements.txt`, ask where to put the environment, and do not claim a plan was validated. Read `$CT/VERSION` and tell the author which tools version you use. Only an installed bundle has that file; in a checkout say that you use the checkout. When the bundle has `VERSION` and the author's CheckThat checkout is known, compare it with `## Version:` in the checkout's `CheckThat/CheckThat_Vanilla.toc`. If they differ, warn that the bundle is stale and name `make install-skill`.
2. Else try two folders up from this file (the skill runs inside the checkout). Call that root `$CT`; use `$CT/.venv/bin/python` as `$PY` if it exists, else `python3` under the same import check and stop rule as step 1.
3. If neither is a root, ask: "Where is your CheckThat checkout?" Say that `make install-skill` in it sets up the skill for use anywhere. Do not draft until you have a root. Do not use the working directory; it may belong to another addon.
4. Read `$CT/docs/test-plan.md`, the format spec and the schema. Read `reference.md` and `example.yaml` beside this file. Read `$CT/docs/debug-logging.md` before the evidence question; if it is missing, say so and go on.

## 1. Interview

Ask **one question per turn** and wait for the answer. For each question say why it matters and which decision it unlocks, and offer a recommended answer where the repository supports one. Ask in this order. Skip a question when the OpenSpec change, specs or code already answer it, and say what you assumed. Code may settle facts (the addon, its slash prefix, which lines it logs). It never settles the author's choices (depth, locale, clients, roles) unless the change states them. Never answer for the author. Required before drafting: scope, addon, characters, output path, locale, depth, clients, log source.

1. **Scope.** "What is in scope: the current branch, a diff (which range), or this session?" Read it. In a second turn, show the list of what changed and what could break and ask the author to correct it. If an OpenSpec change exists, use its proposal, specs and tasks as the checklist.
2. **Addon.** Which addon does the plan test, and which slash prefix does it use? Check it is in `Plan.SLASH` in `$CT/CheckThat/Model/Plan.lua` and `SLASH` in `ct.py`. If not, stop: a plan for that addon needs a CheckThat change first. Say so.
3. **Characters.** "Does any check need data or actions from more than one character?" Most scopes need one. A run belongs to the character that started it, so a check that needs several characters becomes one plan for each character role, and a comparison afterward (section 2). Ask which roles exist and what each one holds or does. Name each role in one short word. There is no limit on the number of roles; two is the usual case.
4. **Output.** "Where should I write the plan?" Suggest `plans/` in the repository you are working in. Accept any path. Ask for the file name. Suggest `<addon>.yaml` for one plan, and `<name>.<role>.yaml` for each plan of a set (for example `keepthat-tally.bank.yaml`). Add the locale for non-English plans (for example `<addon>.deDE.yaml`).
5. **Locale.** Which client locale will the plan run on? Write the plan for that locale only. Authors keep one plan per locale. Do not translate. Player-visible text in the plan uses the strings that locale shows.
6. **Depth.** Sample (a handful of steps) or release plan (full coverage)? What is the riskiest part of the scope? What must never break?
7. **Clients.** Which clients are in scope: `classic-era`, `forever-camelot`, or both? Which steps are for one client only?
8. **Evidence.** Align with the addon's own logging; do not require a CheckThat-style log. Ask these one at a time:
   - What is the debug-log SavedVariable name, its path inside it, and its format (`strings` or `entries`)? Check `LOGS` in `ct.py` and the addon source first, then confirm with the author.
   - Which behaviors already write a log line? Read the addon source for the lines. Do not invent lines.
   - Which scope items write nothing? Those need a player check (see item 9). A result that is a value, or has no log line, can also become a fact: the addon calls `CheckThat.Report` and the plan asserts on a `facts` log source (see "Publish a fact" in `$CT/docs/debug-logging.md`). Offer it beside a new log line, and never write an assertion for a fact the addon does not report.
   - If the addon has no debug log at all, say so once and recommend adding one. Point to `$CT/docs/debug-logging.md` for the pattern and what a good line looks like. Ask: add one now, or draft with player checks? Either way, draft player checks, never invent log lines, and mark each step that would become a log assertion once the log exists (`notes: Becomes a log assertion once <addon> logs <event>.`).
9. **Human eye.** For each changed behavior with no log line: can the author accept a player check, or should the addon gain a log line or report a fact? List suggestions and let the author accept them all or decide one by one. What needs combat, a protected action, or a second client?
10. **Reload and state.** Which steps need `/reload`? Which checks survive a reload and which are per attempt or per session? What setup and cleanup does each step need?
11. **Return path.** Remind the author the result comes back by `/ct export`, then `/reload`, then `ct.py collect`, and then the `ct-verify` skill reads it back. The tool needs the WoW SavedVariables path; ask for it only if the author wants to harvest now. The tool reads `CT_WOW` (the game folder) from `$CT_ENV`, `.ct.env` or `~/.checkthat.env`, so ask for the path once and offer to write it there.

## 2. Draft

Draft **one plan at a time and one step at a time** (section 4 reviews each step as you draft it). Write YAML to the chosen path. Follow `example.yaml` for shape and the schema for fields. The rules that decide the draft:

- **Simple steps by default.** Each step has one player action and one expected result, in short active sentences. When a check needs more, split it into consecutive steps. Draft a compound step (several actions, several expected results or a multi-part assertion set) only when the author asks for it, say that you did, and mark it with `notes: Compound step, drafted on request.`.
- **Start with a version check.** The first step of every plan checks that the game loaded the version under test. A copy of an older build gives results that mean nothing. For a CheckThat plan, run `/ct version` in an `auto` step with a `fact` assertion `key: version`, `op: ge`, `value: major*10000 + minor*100 + patch` (0.17.0 is 1700), and a `facts` log source. For another addon, ask the player to read its version in the AddOns list, or use a fact the addon reports.
- Cover each changed requirement or scenario with at least one step. Add one regression step for the nearest unchanged behavior. Add negative cases, and combat cases when the scope touches them. Keep a sample to a handful of steps; a release plan can be longer.
- Prefer a required `log` assertion where the addon already logs the evidence. Use `diagnostic` only for extra context. Use `absent` for "must not appear". Pick `scope` on purpose: use `attempt` for evidence expected after the step opens (attempts survive `/reload`); use `session` only for a line an earlier step wrote.
- Where nothing is logged, use `verify: [player]` and an `expect` a player understands. Never ask the player to read a log line. A disabled button or a refusal that writes no line is a player check and a gap for section 5. Do not stand in with an unrelated `absent` line.
- A confirmation question that the action itself raises is part of that action, not a second action.
- Put a destructive step (delete, clear, reset) last, and say in its `setup` to export the run first, because it removes evidence.
- Group steps into `categories` (or let each section be one) when the plan has areas a tester may run on their own. Use a `fact` assertion for a value (`between`, `approx`, `type`, `in`), `count` for "how many times" (`min` on an auto step), and the quiet `errors` source (`global.errors`) for "no Lua error". Use `cases` for one check repeated over a list. Read "Unit-test checks" in `$CT/docs/authoring-plans.md`.
- Mark a step `auto: true` only when its required assertions are unconditional log lines or state probes that settle the step alone, with `verify: [assertions]` and no `player`. A required check that something did not happen (`absent`, a `missing` fact, a count with `exactly` or `max`) is allowed only with a `timeout`: the step passes when the time ends with the check still holding, and fails at once if it breaks. CheckThat then records the result itself. A step that needs a human judgment ("it looks right") stays manual. Default an auto step's `timeout` to 120 seconds, and ask the author whether to change it (5 to 300 seconds). Tell them the timeout counts from when the step opens, so it must cover the player's own action time plus the result. At the timeout a contradicted check records fail and missing evidence records unverified, never fail. Use `kind: wait-event` for a step the player finishes by doing something in game. It is valid only on an auto step.
- Ask the author for each step: auto or manual. A manual step waits for a click, so end its `expect` text with the press it needs (for example "Press Pass."). Never leave a tester waiting for a step that will not advance by itself.
- Never assert the line a step's own result press writes (`[ct] step <its id> <verdict>`). CheckThat judges the result before it writes that line, so the step stays unverified. Put such a check on a later step with `scope: session`.
- A check for new UI says what the tester should see: where it appears, which way it grows, what it shows. "It shows" is not enough.
- Every slash command named in step text goes in that step's `action.commands`, and only from the addon's allow list plus `/reload`, `/reloadui` and `/console scriptErrors 0|1`. No `/script`, `/run` or `/dump`. The card shows four command lines, so keep a step to four.
- Text uses native color codes (`|cff99ccffcommand|r`), never Markdown. Sentences are short, active voice, one fact each.
- Tag steps with `clients` only when they apply to one client; a step for both clients has no tag. Add `setup`, `cleanup` and `reload` where the step needs them.
- Never put raw saved variables or real character names in the plan.

### One plan for each character role

When the interview named more than one role, draft one plan for each role. See `keepthat-tally.bank.yaml` and `keepthat-tally.alt.yaml` beside this file.

- Each plan is runnable by its character alone. No step asks the player to log in as another character.
- File names are `<name>.<role>.yaml`. Each preamble names every partner plan file and says to run all of them before verifying.
- A `reviewer` line on the step that completes a comparison (usually in the last role's plan; the other plans need none) names the partner files, the step IDs to compare and the relationship that must hold (for example "both tooltips show the same total"). The `ct-verify` skill reads it. Reference a step as a file name plus a step ID, because step IDs are local to a plan.
- Step IDs stay stable and carry a per-role prefix.
- Compare nothing in game. The comparison happens afterward from the collected results.
- Starting a run uses the last plan imported for that addon. Tell the author to import and start each role's plan on its own character before importing the next.

## 3. Validate

Run `$PY $CT/tools/ct.py validate <plan>` on every plan. Report every problem with its step id and fix it. `validate` fails on a step that asserts its own result line. It warns (without failing) about a slash command named in text but missing from `commands`, and about a first step with no version check; fix each warning.

## 4. Review

Review while you draft: show each step with its evidence choice and client tags and its findings from `reference.md`, and apply only what the author accepts before you draft the next step. A rejected new step stays out of the plan. A rejected edit to an accepted step leaves that step as it was. If the author asks for an edit without wording, ask for the wording before you show it. Offer "accept all" only when the author asks for it.

After the last step, compile the plan (`$PY $CT/tools/ct.py compile <plan> -o <file>.ct`) and, when `$CT` is a checkout (it has `tests/replay_plan.lua`), run `luajit $CT/tests/replay_plan.lua <file>.ct` from `$CT`. It plays every step in the fake client and exits 1 on a problem: a step that never settles, a card that shows a step twice, a step never reached. Show its result in the review and fix each problem before you call the plan final. In an installed bundle there is no replay: say so.

Then show the author:
- Coverage: each scope item and the step(s) that cover it; gaps in bold. When `$CT` and the addon source are at hand, `$PY $CT/tools/ct.py coverage <plan...> --addon-src <addon folder>` lists the subcommands, settings and spec requirements no step touches; a step or section names a requirement with `covers: [heading text]`.
- For a set of plans: each preamble names every partner file, and the reviewer line names the partner files and step IDs.
- The checklist in `reference.md`, with each finding tied to a step id.

Re-run `validate` after changes, then run `compile <plan> -o <file>.ct` on every final plan. For a CheckThat plan in a checkout, replay it too: `luajit tests/replay_plan.lua <file>.ct [hooks.lua]` (see "Replay a plan" in `$CT/docs/authoring-plans.md`). Fix every problem, and check the text of every step it warns about. For a set, tell the author the import order: one role per character, each imported and started before the next import.

## 5. Gaps

For every step that has no log evidence, offer to open an issue in the addon's repository: `gh issue create`, with the gap, the code involved and a possible log line or fact (the guarded `CheckThat.Report` call and its key, from `$CT/docs/debug-logging.md`). If the addon has no debug log, offer one issue for the log facility (the pattern in `$CT/docs/debug-logging.md`) plus one issue per needed line, each naming the steps it unlocks. No personal names. Ask first; never open it unasked.

## Finish

Run `compile <plan> -o <file>.ct` on every final validated plan if you have not since the last edit. Report: each plan path, each `.ct` path, step counts, validate results, open gaps, and the return path (export, `/reload`, `ct.py collect`, then `ct-verify`). Do not claim the plan was run.
