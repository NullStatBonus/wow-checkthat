---
name: ct-verify
description: Read a finished CheckThat (CT) test run back against its plan. Collects the saved variables, matches each step to its recorded result and evidence, compares runs across characters, and reports pass, fail, unverified and contradicted steps. Use when the user asks to verify, check or review a finished CT run, a /ct export string, or a copied /ct log report.
---

# Verify a finished CT run

Report what a run recorded against what its plan asked. Report only. Never edit a plan, never run the game, never put raw saved variables in Git.

## 0. Locate the tools

The tools root holds `tools/ct.py`, `tools/sv2json.lua`, `CheckThat/Model/Json.lua` and `CheckThat/Model/Plan.lua`. A path counts as the root only when all four exist under it.

1. Try `ct/` beside this file.
2. Else try `../ct-test-plan/ct`, the bundle `make install-skill` puts next to this skill. Use `../ct-test-plan/.venv/bin/python` as `$PY` if it exists. A plugin install has no private Python: use `python3` when `python3 -c "import yaml, jsonschema"` succeeds. If it fails, stop and tell the author to run `python3 -m venv <dir> && <dir>/bin/pip install -r $CT/requirements.txt`, and ask where to put the environment.
3. Else try two folders up from this file (the skill runs inside the checkout). Use `$CT/.venv/bin/python` as `$PY` if it exists, else `python3` under the same import check and stop rule as step 2.
4. If none is a root, ask: "Where is your CheckThat checkout?" Say that `make install-skill` in it sets up both skills. Do not use the working directory.

Read `$CT/VERSION` and tell the author which tools version you use. Only an installed bundle has that file; in a checkout say that you use the checkout. `collect` needs `luajit` on the PATH. If it is missing, say so and stop; do not guess results from raw files.

## 1. Ask what to verify

Ask one question at a time. Skip what the author already gave.

1. **Plans.** "Which plan files did you run?" For a plan set (names like `<name>.<role>.yaml`), read every partner the preambles name.
2. **Results.** Prefer the full result: the saved run data. Ask for the WoW game folder (`CT_WOW`, also read from `$CT_ENV`, `.ct.env` or `~/.checkthat.env`) or a folder of copied SavedVariables. A `/ct export` string also holds the full run. A pasted `/ct log` report is partial evidence only: it has a summary, failures and a bounded debug log, not every step's attempts.
3. **Evidence folder.** Suggest `evidence/` in the working directory. Never write under this skill's folder. Remind the author to keep it out of Git.

## 2. Collect

Pass `--dest` every time, because the default sits under the tools root.

- Saved variables: `$PY $CT/tools/ct.py collect --wow <game folder> --dest <evidence>` (or `--src <WTF folder>`).
- An export string: `$PY $CT/tools/ct.py import-results <string or file> --dest <evidence>`.

After collecting, run `$PY $CT/tools/ct.py status --dest <evidence>`. It lists every unreadable revision, every conflict or decode failure `collect` logged and any run near the 2 MB export limit, and exits 1 when something is wrong. Tell the author what it names before you read steps. It does not judge test results.

`collect` exits 1 and names the file when it cannot decode a saved-variables file. Report that and stop. A run folder holds `r<N>.json` revisions. Use the highest revision of each run ID. Zero new revisions is fine when you collected the same data before.

## 3. Bind each run to its plan

A run stores `planDigest`, not the plan. The digest is the 8-hex field of the compiled string (`!CT1!<digest>!...`), with a `-2`, `-3` suffix when two plans collided.

1. For each role, compile the plan file (`$PY $CT/tools/ct.py compile <plan> -o <file>.ct`) and read its digest, or take the plan from the copied saved variables: `$PY $CT/tools/ct.py sv2json <evidence>/sv/<CheckThat copy>` and look in `CheckThatDB.planStore[<digest>]` of the JSON it prints. The copy's name carries a hash, so list `<evidence>/sv/` first. `planStore` holds only the plans that runs in that file used, so a plan file is the usual source; when both exist, they must give the same digest.
2. Check the run's `planDigest` against it. If you cannot establish the exact plan, say so before you read any assertion index or reviewer text, and judge only the recorded verdicts.
3. A run from another plan, or a plan that changed since the run, does not count for that role.

## 4. Read each step

`$PY $CT/tools/ct.py report --dest <evidence>` prints a `result:` line for each run, keeps the failed or unverified attempts of a step that later passed, and shows the Lua error stack raised during a failed or unverified attempt (matched by time, so it may say it also fits another attempt). `--format json` gives step results as data (add `--stacks` for error stacks; it has no earlier attempts), and `--strict` exits 1 on any failed or unverified step.

A step record holds the effective `verdict` and attempts. Run revisions need not be contiguous (`r2.json` can be the first). Each attempt holds `claimed` (what the player or CheckThat recorded), `by` (`player` or `auto`), `evidence` (`matched`, `contradicts`, `unverified` or `diagnostic-only`) and `outcomes`, one per assertion in plan order, each `result` (`pass`, `fail`, `unverified`), `why`, and `diagnostic`. A failed or unverified attempt may also hold `excerpt`: the first new lines of each log the step checks, keyed by log source. Quote them when you explain a failure. Use the last finished attempt.

A run may hold `categories`, `cat` (step id to category) and `selected`. `report` prints one `categories:` line with blue, yellow, red, green or grey for each category; a run saved before categories has none. The effective verdict can stay `pass` while the evidence contradicts it, so never read the verdict alone. `claimed` and `by` sit on the attempt, not on the step. Report four things apart for every step: effective verdict (`pass`, `partial`, `fail`, `unverified`, `skip`, `pending`, `inapplicable`, `deselected`; a deselected step was not picked at the start and is not a gap), claimed verdict, who set it, and the evidence.

- **Contradicted.** The claim is `pass` or `partial` and a required assertion recorded `fail`: a state assertion failed, or a forbidden line appeared. A diagnostic assertion never contradicts.
- **Unverified.** A required assertion found no evidence. A hand `pass` with a required log line missing is this, as the runner records it. It is not contradicted.
- **No evidence.** The step has no assertions, so its attempts hold no `evidence` field and no `outcomes`. Say so and suggest one log line that would prove it.
- Cite run ID, revision, step ID, attempt number and assertion index. Quote a log line only when the data holds it. An exported assertion may hold only a result; then cite the index and the `why`.

## 5. Plan sets: compare across characters

For each `reviewer` line that names partner files, step IDs and a relationship:

1. Resolve each reference as a role file plus a step ID. Step IDs are local to a plan.
2. A role needs exactly one eligible run: the right plan digest, the latest revision of its run ID, and a different character from every other role. If more than one eligible assignment of runs to roles remains, list the runs (run ID, character, start time converted from the run's `started` epoch seconds, and counts of steps by verdict: pass, fail, open) and ask the author for run IDs. If exactly one assignment exists, use it without asking.
3. A role with no collected run reads unverified, never pass. Name the missing role.
4. Compare what the reviewer line asks, and report the relationship as held, broken or unverified, with the cited values. The number of roles is not limited.

## 6. Report

Start with the `status` result (healthy or not) in one line. Print one table per run (step, effective, claimed, by, evidence, citation), then the cross-character results, then a short list of: contradicted steps, unverified steps, steps with no evidence, and suggested assertions or log lines. Say what you could not judge and why (partial input, plan not established, missing role). Do not edit the plan; the author decides what to change. Do not commit the evidence folder.

## Rules

- Report only. Never edit a plan, never send input to the game, never open or answer a game prompt.
- Keep raw saved variables and collected evidence out of Git. Anonymize character names if you quote a fixture.
- A missing run or plan is "unverified", not "pass".
