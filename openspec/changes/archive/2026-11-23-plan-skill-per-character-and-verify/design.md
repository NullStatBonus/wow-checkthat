# Design

## Context

The skill lives in `skills/ct-test-plan/`: `SKILL.md`, `reference.md` and `example.yaml`. `make install-skill` bundles it with the plan tools and a private Python. `tools/ct.py` has `collect`, `report` and `import-results`. `collect` runs `luajit` with `tools/sv2json.lua`, which loads `CheckThat/Model/Json.lua`. Neither Lua file is in `BUNDLE`, so an installed `collect` can copy files, warn, and extract no runs. The default evidence folder sits under the tools root, which is the bundle, and a reinstall replaces it.

A stored run keeps the player's claimed verdict apart from the effective verdict. A required positive log assertion with no line gives `unverified`, not `fail`. A run stores its plan digest, not the plan: the app keeps plan copies in `planStore`, an export carries the run only, and `collect` writes only the run to revision JSON. An exported assertion may hold only its result, not the matched line. `latest_runs` picks the latest revision for each run ID. Starting a run uses the last plan imported for that addon.

## Goals / Non-Goals

**Goals:**
- Interview and draft in small steps the author can follow, with simple steps by default.
- Plans that one character can finish alone, for any number of roles.
- A read-back that pairs the right runs and compares what each character recorded.

**Non-Goals:**
- A plan-format field that links plans. It would change `CheckThat/Model/Plan.lua`, force an addon release, and the convention may be enough. Open an issue if it proves too loose.
- Python logic in `ct.py` to match results to steps. The skill reads the collected run data. Add tooling only if the read-back proves unreliable.
- Harvest for any OS and environment (#31), the plugin and the commands (#18, #17). Change `plan-skill-plugin-and-commands` covers #18 and #17. #31 needs its own change.

## Decisions

1. **Per character role first, then one step at a time.** The skill settles the roles before it drafts. Alternative: draft one plan, split it later. Rejected: the split changes step IDs, setup and evidence.
2. **Plan sets link by convention.** Files are `<name>.<role>.yaml`. A preamble names every partner file. A `reviewer` line names the partner files, the step IDs to compare and the relationship that must hold. N roles use the same rule; two is the usual case. Alternative: a format field. Rejected for now.
3. **Runs bind to plans by digest.** `ct-verify` gets each role's plan from the role's compiled `.ct` or plan file, or from `planStore[run.planDigest]` in the copied SavedVariables, and checks the run's digest against it. If it cannot establish the exact plan it says so before it reads any assertion index or reviewer text. It resolves each reviewer reference as (role file, step ID), because step IDs are local to a plan. It uses the latest revision of each run ID and requires distinct characters. It asks the author for run IDs only when more than one eligible assignment of runs to roles remains; a unique assignment proceeds without asking. It never picks silently.
4. **Two inputs, two strengths.** Saved run data (via `collect`) or an `/ct export` string (via `import-results`) gives every step's attempts and results. A pasted `/ct log` report holds a summary, failures and a bounded debug log. The skill treats it as partial evidence and says which steps it cannot judge. Citations use run ID, revision, step, attempt and assertion index.
5. **Report verdict and evidence separately.** For each step the report shows the effective verdict (`pass`, `partial`, `fail`, `unverified`, `skip`, `pending`, `inapplicable`), the attempt's `claimed` verdict, who set it (`by`) and the recorded evidence with its required outcomes. *Contradicted* means a hand `pass` or `partial` while a required assertion recorded `fail` (a failed state assertion or a forbidden line that appeared). A diagnostic assertion never contradicts. A hand pass with a required log line missing reads *unverified*, as the runner records it. The report cites the assertion index when the data has one, quotes a line only when the data holds it, and lets a partial report leave out identifiers it lacks.
6. **`ct-verify` reports only.** It never edits a plan, never drives the game, and keeps raw saved variables out of Git. It writes collected evidence to a folder it is given or to the working directory's `evidence/`, never under the installed skill. It passes `--dest` explicitly to both `collect` and `import-results`, because their default is under the tools root, which is the bundle.
7. **Simple steps are the default.** `SKILL.md` already advises one action and one result per step. The change makes it a requirement and adds the opt-in for a compound step. A one-action step gives a clear Pass or Fail and a clear log line.
8. **Interview rules replace the old requirements.** The delta uses `MODIFIED` for the interview and review requirements, so no older text conflicts. It keeps final coverage review, locale-specific names, validation and compile for every partner plan.
9. **Tests cover what code decides.** Extend `tools/test_ct.py` for the bundle (install into a temp folder, run `collect` from a sibling directory on a synthetic SavedVariables file, assert the extracted run and step). Verify behavior of the skills with anonymized fixtures of known verdicts and a scripted interview.

## Risks / Trade-offs

- [One question per turn lengthens the interview] → the skill skips answered questions, and accept all stays for review.
- [The convention is loose] → `ct-verify` reports a partner role with no run as unverified, never as pass, and asks for run IDs when pairing is ambiguous.
- [`collect` needs `luajit` on the machine] → say so in the README and in the skill; report a decode failure instead of exiting clean with no runs.
- [Skill prose is hard to regression-test] → fixtures and a scripted interview in `docs/test-plan.md`.
