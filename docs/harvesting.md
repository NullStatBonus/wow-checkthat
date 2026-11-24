# Collect evidence

After a run, `/reload` or log out so the game writes the saved variables. Then read them on your computer with `tools/ct.py`.

`collect` and `report` need LuaJIT (`luajit` on your PATH) to decode saved variables.

## Collect, check and report

```
.venv/bin/python tools/ct.py collect     # copy saved variables, runs, error stacks and screenshots into evidence/
.venv/bin/python tools/ct.py status      # is the evidence readable and complete?
.venv/bin/python tools/ct.py report      # write evidence/REPORT.md
```

- **Source.** `collect` reads `../shared-addon-resources/saved` by default. `--wow <game dir>` (or `CT_WOW`) collects `_classic_era_` and `_forever_` with their `WTF` and `Screenshots` folders. `--src <WTF dir>` (or `CT_WTF`) names one folder and wins.
- **Report.** `REPORT.md` gives each run a `result:` line (`ok`, `UNVERIFIED` or `FAIL` with counts) and a table of every step: verdict, evidence (`met`, `bad`, `missing` or `none`), attempt count and note. Detail lines follow for steps that did not pass. A step that passed after a rerun lists its earlier failed or unverified attempts too. A failed or unverified attempt shows the Lua error that was raised while it was open, with its call stack. The match is by time (whole seconds), so a stack that also fits another attempt says so.
- **Status.** `status` prints one row per run at its newest readable revision: steps done over steps that apply, fail, unverified and open counts, age, and the export size as a percent of the 2 MB limit (`size~`, an estimate from the saved run). It names every revision file it cannot read and every conflict or decode failure `collect` met (kept in `evidence/problems.log`; delete the file once you have looked). It judges the evidence, not the test result. `--json` prints the same as JSON.
- **Exit codes.** `status` exits 0 when every revision is readable and nothing conflicts, 1 when there is no run, a revision is unreadable, a conflict was logged or a run is over 80% of the size limit. `report --strict` exits 1 when any step failed or is unverified (a pass or partial whose required evidence failed or has no result counts too), or when there are no runs. Without `--strict` `report` exits 0.
- **Show.** `show <run>` prints one run, as the report does. `show <run> <step>` prints one step with every attempt, its log lines and its error stacks. `<run>` can be part of the run id when only one run matches. A wrong run or step name exits 2 and lists the choices.
- **Failed only.** `report --failed-only` keeps the runs and steps that failed or are unverified, the same steps `--strict` counts.
- **Watch.** `status --watch` prints the status again every `--interval` seconds (default 5) until Ctrl-C. It exits with the last status code. Use it while you collect and fix. It does not go with `--json`.
- **Formats.** `report --format json` prints the steps, counts and categories as JSON. `report --format junit` prints JUnit XML for a CI job: a suite for each run and category, a case for each step. Fail and unverified are failures (the `type` says which). Pending, skip, deselected and not-for-this-client steps are skipped with the reason. Partial passes and keeps its note in `system-out`. For json and junit, `--out <file>` writes the file instead of printing. Call stacks can hold private paths, so json and junit leave them out unless you add `--stacks`.
- **Log lines.** A run keeps about 60 000 bytes of log lines in failed attempts. When it holds more, the oldest attempts lose theirs first. They keep their attempt records.
- **Results string.** Paste one from `/ct export` with `.venv/bin/python tools/ct.py import-results "<string>"`. A file path works too.
- Keep `evidence/` out of Git.

## Local paths

`tools/ct.py` reads `KEY=VALUE` lines from `$CT_ENV`, `.ct.env` in the working folder (git-ignored) and `~/.checkthat.env`, in that order. A variable already set wins, and a flag wins over both. `CT_WOW` is the game folder. `CT_WTF` and `CT_SHOTS` name one folder each.

## Screenshots

Set `screenshot: true` on a step. The card asks for Print Screen. The addon never captures. `collect` copies screenshots taken inside an attempt's time window (`--shots <folder>`, default `Screenshots` beside `--src`).

## Classic Era per-character data

Some addons keep a log per character. On Classic Era, ClosestVendor's `ClosestVendorCharDB` is one. A copy that takes only account-level saved variables misses it. Run `collect --src "<WoW>/_classic_era_/WTF"` against the real folder instead.

## Windows

Double-click `tools/Copy-CheckThatEvidence.bat`. It runs `Copy-CheckThatEvidence.ps1` beside it. `/reload` or log out first so the game writes the files.

It copies CheckThat and the three addons' saved variables (including Era per-character files) and Screenshots into `evidence-src/`. Then, on a computer with LuaJIT, run:

```
.venv/bin/python tools/ct.py collect --src evidence-src
.venv/bin/python tools/ct.py status
.venv/bin/python tools/ct.py report
```

The Windows PC does not need LuaJIT or Python for the copy step.

## Categories in the report

`report` prints a `categories:` line for each run that holds categories: blue, yellow, red, green or grey with the count of steps with a result over picked steps, or "not picked". Steps of a category that was not picked read `deselected` and are not counted as unverified. A run saved before categories prints no such line.
