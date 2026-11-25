# Collect evidence

After a run, `/reload` or log out so the game writes the saved variables. Then read them on your computer with `tools/ct.py`.

`collect`, `status` and `report` decode saved variables with a Python reader. They do not need LuaJIT (a test checks that the reader gives the same JSON as `tools/sv2json.lua` on every fixture). `replay` and `offline` still need `luajit`. To judge a plan against a saved-variables fixture without the game, see [Check a plan against saved variables](authoring-plans.md#check-a-plan-against-saved-variables).

## Collect, check and report

```
.venv/bin/python tools/ct.py collect     # copy saved variables, runs, error stacks and screenshots into evidence/
.venv/bin/python tools/ct.py status      # is the evidence readable and complete?
.venv/bin/python tools/ct.py report      # write evidence/REPORT.md
```

- **Source.** `collect` reads `../shared-addon-resources/saved` by default. `--wow <game dir>` (or `CT_WOW`) collects `_classic_era_` and `_forever_` with their `WTF` and `Screenshots` folders. `--src <WTF dir>` (or `CT_WTF`) names one folder and wins.
- **Which files.** With no plan, `collect` copies the saved variables of CheckThat, KeepThat, DontDoThat and ClosestVendor. `--plan <plan.yaml>` copies CheckThat's file, the file named for the plan's `addon`, and every file that assigns a `logs.*.global` of the plan, so a plan for any addon is collected. Each file prints its path, modified time and age (`source: ..., modified 2026-11-24 21:03:10, 12m ago`), so a stale copy shows. A plan global that no file defines prints a warning on stderr and `collect` still exits 0.
- **Report.** `REPORT.md` gives each run a `result:` line (`ok`, `UNVERIFIED` or `FAIL` with counts) and a table of every step: verdict, evidence (`met`, `bad`, `missing` or `none`), attempt count and note. Detail lines follow for steps that did not pass. A step that passed after a rerun lists its earlier failed or unverified attempts too. A failed or unverified attempt shows the Lua error that was raised while it was open, with its call stack. The match is by time (whole seconds), so a stack that also fits another attempt says so.
- **Status.** `status` prints one row per run at its newest readable revision: steps done over steps that apply, fail, unverified and open counts, age, and the export size as a percent of the 2 MB limit (`size~`, an estimate from the saved run). It names every revision file it cannot read and every conflict or decode failure `collect` met (kept in `evidence/problems.log`; delete the file once you have looked). It judges the evidence, not the test result. `--json` prints the same as JSON.
- **Compare runs.** `ct.py diff <run A> <run B>` and `ct.py trend` read the collected runs. See [Compare runs](#compare-runs).
- **Newer format.** A run saved in a newer major format is refused with its file name and the reason. `collect` stores nothing of it and writes `refused.json`. `status` lists it, `report` warns (it shows an older revision when there is one, and says when the run is missing), and `report --strict` fails until a later `collect` stores a revision at least as new. `import-results` refuses it before it reads anything else. Update the tools folder. See [Results format](results-format.md).
- **Exit codes.** `status` exits 0 when every revision is readable and nothing conflicts, 1 when there is no run, a revision is unreadable, a conflict was logged or a run is over 80% of the size limit. `report --strict` exits 1 when any step failed or is unverified (a pass or partial whose required evidence failed or has no result counts too), or when there are no runs. Without `--strict` `report` exits 0.
- **Browse.** `browse` (or `tools/ct_tui.py`) opens a read-only viewer in the terminal: runs (failures first), the steps of a run, and one step with its attempts. It needs a terminal and Textual, which is not installed with the plan tools: `.venv/bin/python -m pip install -r requirements-tui.txt`. Without a terminal it prints the `status`, `report --failed-only` and `show` commands that give the same facts. See [Browse the evidence](#browse-the-evidence).
- **Show.** `show <run>` prints one run, as the report does. `show <run> <step>` prints one step with every attempt, its log lines and its error stacks. `<run>` can be part of the run id when only one run matches. A wrong run or step name exits 2 and lists the choices.
- **Failed only.** `report --failed-only` keeps the runs and steps that failed or are unverified, the same steps `--strict` counts.
- **Watch.** `status --watch` prints the status again every `--interval` seconds (default 5) until Ctrl-C. It exits with the last status code. Use it while you collect and fix. It does not go with `--json`.
- **Check detail.** Under a failed attempt the report names each check that did not pass: the rule, the counts, and the lines that decided it (`line 7: ...`). The same lines are marked `>` in the log lines kept for the attempt. `--format json` has them as `checks` on each step, with positions and counts; `--lines` adds the text, the values and the full rule (without it a rule shows as its `shape`, with the plan's literals left out). JUnit gives the same checks of the attempt the result comes from. A passing attempt that kept a failed diagnostic is listed too. How the data is laid out: [Which lines decided a check](features.md#which-lines-decided-a-check).
- **Formats.** `report --format json` prints the steps, counts and categories as JSON. `report --format junit` prints JUnit XML for a CI job: a suite for each run and category, a case for each step. Fail and unverified are failures (the `type` says which). Pending, skip, deselected and not-for-this-client steps are skipped with the reason. Partial passes and keeps its note in `system-out`. With `--stacks`, a step that failed and later passed lists the stacks of its failed attempt in `system-out`, and json holds them under `attemptStacks` for each attempt. A stack whose time fits two attempts says so. A step reopened by Undo or a rerun reads "awaiting retry" with evidence `none` in the table, not its older note and evidence. Json and junit give it the same reason, and json adds `awaitingRetry`. For json and junit, `--out <file>` writes the file instead of printing. Call stacks can hold private paths, so json and junit leave them out unless you add `--stacks`.
- **Log lines.** A run keeps about 60 000 bytes of log lines in failed attempts. When it holds more, the oldest attempts lose theirs first. They keep their attempt records.
- **Results string.** Paste one from `/ct export` with `.venv/bin/python tools/ct.py import-results "<string>"`. A file path works too.
- Keep `evidence/` out of Git.

## Coverage of the evidence

`ct.py coverage <plan...> --addon-src <folder> --evidence` joins the newest finished run of each plan to the addon's subcommands, settings and spec requirements: `passed`, `failed` (failed or unverified) or `never-run`. See [Check what the plans cover](authoring-plans.md#check-what-the-plans-cover).

## Compare runs

```
.venv/bin/python tools/ct.py diff <run A> <run B> [--format md|json] [--strict] [--include-open]
.venv/bin/python tools/ct.py trend [--addon X] [--title T] [--by client|character|build|version] [--last N] [--format md|json] [--include-open]
```

Both read the newest readable revision of each collected run. Each step is judged as `report` judges it, so a pass with a contradicted check counts as a fail. A run id can be a part of the id that names one run.

- **Diff labels.** `regressed` (pass or partial, then fail), `fixed` (fail or unverified, then pass or partial), `newly-unverified` (pass, then unverified), `still-failing`, `not-comparable` (one side is pending, skipped, deselected, not for that client or reopened), `added` and `removed` (a step id only one run has). Unchanged steps are counted, not listed. The header names each run's client, build, character, plan digest and CheckThat version, and says "plan changed" when the digests differ.
- **Exit codes.** `diff` exits 0 and, with `--strict`, 1 when a step regressed. It exits 2 for an unknown run, a run that was left out, or a run that has not ended.
- **Unfinished and newer runs.** A run that has not ended is left out unless you add `--include-open`. A run in a newer format is never read: `diff` refuses it by name, and `trend` leaves it out and lists it as a warning.
- **Same plan, same step?** Equal plan digests mean equal steps. Otherwise the tool compares a fingerprint (a hash of the whole step) from the plan the run stored. The plans come from the collected CheckThat saved variables (`planStore`). A changed step is `not-comparable` (`~` in a trend). When a plan is not stored, the step is `not-comparable` (`?` in a trend) and a warning names the digest. The tool never guesses.
- **Trend.** One table for each addon and plan title, so plan edits stay in one table. Columns are runs, oldest first, named 1, 2, 3 and listed above the table; `--by` adds that value of each run to its line (`version` is the CheckThat version that wrote the run). `--last` keeps the newest runs. Cells are `P` pass, `p` partial, `F` fail, `U` unverified, `-` not run, blank for no such step. A step that passed in one run and failed or went unverified in another is marked `flaky`. It exits 2 when no run matches.
- **Limits.** Runs that CheckThat pruned before `collect` are not there. The version of the addon under test is not recorded yet, so a trend cannot name it.

## Browse the evidence

```
.venv/bin/python -m pip install -r requirements-tui.txt   # once
.venv/bin/python tools/ct.py browse
```

The viewer only reads. Collect in a shell, as before. The screen reloads when the evidence folder changes, and `r` reloads at once.

| Screen | Shows | Keys |
| --- | --- | --- |
| Runs | A strip counts the runs: failing, unverified and no flags (each run counts once, fail first), and shows the first problem `status` finds. Each row has a result word and mark (`✗ FAIL`, `? UNVER`, or `—` for no flags), the run id and steps done over steps that apply. From 76 columns it adds plan, revision, fail and unverified counts and age. Failures first, then unverified, newest first. | Enter opens a run |
| Steps | A header with the run result and counts, and the filter. From 76 columns it adds a chip for each category (`✗` red, `?` yellow, `✓` green, `…` still open, `·` empty, `–` not picked) with steps done over total. A chip follows the evidence, so an overturned pass makes it red. Each row has a result word and mark and the step id. From 76 columns it adds category and reason. A filter with no match says "No matching steps". | `f` cycles all, fail, unverified. `/` cycles the categories. Enter opens a step. Esc goes back. |
| Step | A colored banner with the result (red fail, yellow unverified, green pass) and the player's verdict. It warns when the evidence overrules a pass. Below it an attempt strip (the shown attempt is filled, an open one is hollow) and one attempt: its facts, the note, a table of required and diagnostic checks, the log lines kept with line numbers, and each error raised while it was open with its stack, frame by frame. | `[` and `]` move between attempts. Esc goes back. |

Everywhere: `e` shows what an export will write (scope, format, file, stacks) and writes it on Enter. `c` shows the collect command. `?` shows the keys. `q` quits. Marks and words carry every state, so nothing depends on color. `NO_COLOR` turns color off. Evidence shows as plain text. Stacks stay out of a JSON or JUnit export until you press `s`, because they can hold private paths.

## Local paths

`tools/ct.py` reads `KEY=VALUE` lines from `$CT_ENV`, `.ct.env` in the working folder (git-ignored) and `~/.checkthat.env`, in that order. A variable already set wins, and a flag wins over both. `CT_WOW` is the game folder. `CT_WTF` and `CT_SHOTS` name one folder each.

## Screenshots

Set `screenshot: true` on a step. The card asks for Print Screen. The addon never captures. `collect` copies screenshots taken inside an attempt's time window (`--shots <folder>`, default `Screenshots` beside `--src`). `--shot-slack SECONDS` (default 2) widens or narrows each window on both sides. A file taken outside every window but within an hour of an attempt is not copied. `collect` counts these files on every run ("2 screenshots matched no attempt"). `--verbose` names each one with the nearest step and the gap in seconds. `--all-shots` copies them to `runs/<id>/unassigned-shots/` of the nearest run. No step lists them. With `--wow`, a folder prefers the runs of its own client. If a screenshot inside a step is still missing on a network mount, the file times may differ from the game clock. Read the gap from `--verbose` and raise `--shot-slack`. The real skew is not measured yet: [#95](https://github.com/NullStatBonus/wow-checkthat/issues/95).

## Classic Era per-character data

Some addons keep a log per character. On Classic Era, ClosestVendor's `ClosestVendorCharDB` is one. A copy that takes only account-level saved variables misses it. Run `collect --src "<WoW>/_classic_era_/WTF"` against the real folder instead.

## Windows

Double-click `tools/Copy-CheckThatEvidence.bat`. It runs `Copy-CheckThatEvidence.ps1` beside it. `/reload` or log out first so the game writes the files.

It copies CheckThat and the three addons' saved variables (including Era per-character files) and Screenshots into `evidence-src/`. Each copied file prints its modified time and age, and a missing file prints a warning. To copy other addons, run the script with `-Names` (file names without `.lua`; CheckThat is always copied): `powershell -File tools\Copy-CheckThatEvidence.ps1 -Names MyAddon,OtherAddon`. Then run the tools with Python:

```
.venv/bin/python tools/ct.py collect --src evidence-src
.venv/bin/python tools/ct.py status
.venv/bin/python tools/ct.py report
```

The Windows PC does not need Python for the copy step, and no step needs LuaJIT.

## Categories in the report

`report` prints a `categories:` line for each run that holds categories: blue, yellow, red, green or grey with the count of steps with a result over picked steps, or "not picked". Steps of a category that was not picked read `deselected` and are not counted as unverified. A run saved before categories prints no such line.
