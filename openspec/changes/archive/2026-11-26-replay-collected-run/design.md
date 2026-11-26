## Context

#223 and #226 both come from reading a run back after a ClosestVendor test. `replay --sv` (`replay_plan`, `tools/replay_sv.lua`) already judges checks against saved-variables files; it judges each check against the whole log, as `scope: session` does, and skips checks that need the step's window. `collect` copies each saved-variables file to `evidence/sv/<path with __>.<sha1[:10]>.lua` and stores each run revision under `evidence/runs/<id>/r<n>.json`. `report --expect-version` is a typed value today.

## Goals / Non-Goals

**Goals:**
- One command judges a revised plan against a collected run.
- `report` gets the expected version from the TOC without typing it.

**Non-Goals:**
- Judging each step in its own window. A finished attempt drops its log snapshots (`Run.lua`), and debug lines carry no time (#59), so the step windows are not in the collected files. Checks that need the window stay "skipped", as with `--sv`.
- Changing what `collect` records. Selection uses what it already writes.

## Decisions

- **The CheckThat copy is the one that holds the run.** Decode each collected `CheckThat.lua` copy (newest first, by file time) and take the first whose `CheckThatDB.global.runs[<id>].revision` equals the newest stored revision. This ties the files to the run without new bookkeeping.
- **Client and account from that copy's path.** A copy name is the source path with `__` for separators, so the part up to and including `Account__<name>` names the client folder and account. Other copies must share that prefix.
- **Character folder match.** Character files sit at `Account__<name>__<folders>__SavedVariables__<file>`. Era uses `<Realm>__<Name>`, Forever `<id>__<Name>-<Realm>`. A folder matches the run's `character` (`Name-Realm`) when its last part equals it, or when its last part is the name and the part before is the realm with spaces removed. A run whose realm is `?` matches on the name alone. Copies of other characters are never passed, because per-character databases share one global name.
- **Same collect by file time.** `collect` writes each copy at collect time and stores each content once (the name holds its hash), so a file that did not change keeps the copy of its first collect. The content in effect at the CheckThat copy's collect is therefore the newest copy no later than it, with one minute of slack for one collect's own seconds (a larger slack would take the next collect's copy when two collects are minutes apart). "Closest in time" was the first idea; a real evidence folder showed it warns on every unchanged file. When every copy is later, take the earliest and warn that it may hold lines written after the run.
- **Report default.** Reuse `plan_toc` and `toc_version` from #221. Print `expected version 1.13.1, from CV_Vanilla.toc` before the warnings.

## Risks / Trade-offs

- A copy whose file time changed (a backup restore) can pick the wrong collect. → The command lists every file it used and warns about a gap.
- Decoding many CheckThat copies is slow on a large evidence folder. → Newest first, stop at the first match.
