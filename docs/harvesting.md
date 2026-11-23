# Collect evidence

After a run, `/reload` or log out so the game writes the saved variables. Then read them on your computer with `tools/ct.py`.

`collect` and `report` need LuaJIT (`luajit` on your PATH) to decode saved variables.

## Collect and report

```
.venv/bin/python tools/ct.py collect     # copy saved variables, runs and screenshots into evidence/
.venv/bin/python tools/ct.py report      # write evidence/REPORT.md
```

- **Source.** `collect` reads `../shared-addon-resources/saved` by default. `--wow <game dir>` (or `CT_WOW`) collects `_classic_era_` and `_forever_` with their `WTF` and `Screenshots` folders. `--src <WTF dir>` (or `CT_WTF`) names one folder and wins.
- **Report.** `REPORT.md` starts each run with a table of every step: verdict, evidence (`met`, `bad`, `missing` or `none`), attempt count and note. Detail lines follow for steps that did not pass.
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
.venv/bin/python tools/ct.py report
```

The Windows PC does not need LuaJIT or Python for the copy step.
