# Which tool to use with CheckThat

Written 2026-11-24. Tool details change: check the page before you rely on a row.

CheckThat is for what only a person in the live client can show: a window opens, a vendor sells, a bag sorts. Have your addon report facts with `CheckThat.Report` and write a debug log that the plan can read.

## What CheckThat does not do

- It never runs plan text as code.
- It does not replace API calls with fakes.
- It never sends input. Every protected action is a real click or key press by the player.

## Better with: optional addons

CheckThat needs no other addon. These make it better when they are installed. None is a dependency, and every path that reads them works when they are missing.

- **BugGrabber.** When it holds the error handler, CheckThat reads its error counts and its stored stack instead of setting its own handler. Without it, CheckThat sets its own. See the Lua errors item in [Feature reference](features.md).
- **BugSack.** Shows the same errors with the full stack and locals. CheckThat keeps only a short stack and never the locals.
- **The addon under test.** Its debug log and its facts are the evidence. A plan for one of them needs that addon. CheckThat itself loads without any of them: the TOC has no required dependency and lists only BugGrabber under `OptionalDeps`.

## Sources read

- BugGrabber: WowAce project page (version 12.1.1), read 2026-11-24. BugSack: GitHub page, read 2026-11-24.

## Stable commands

From 1.0 these `tools/ct.py` commands keep their arguments and output: a change only adds. Each JSON output and each JSON file they write for a reader has `"format": 1`. It rises only when a key changes meaning or goes. A new key does not raise it, so ignore keys you do not know.

- `validate`
- `compile`
- `coverage`
- `replay`
- `offline`
- `replay-flow`
- `lines`
- `decode`
- `from-md`
- `sv2json`
- `collect`
- `doctor`
- `drift`
- `report`
- `show`
- `browse`
- `status`
- `import-results`
- `diff`
- `trend`
- `setup`

`recordings` and `census` are maintainer tools. Their help starts with "maintainer tool, output may change". The census manifests and the recordings have their own `format`. `from-md` writes a plan and `sv2json` prints saved variables as they are, so their output follows the plan format and the game's data. `decode` prints the plan or run as it is, and those carry `ct` and `formatRev` ([Results format](results-format.md)). The evidence folder's bookkeeping file `refused.json` is not a promise.
