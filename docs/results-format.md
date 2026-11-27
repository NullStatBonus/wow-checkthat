# Results format

The saved run record is the contract between CheckThat and every tool that reads a run: `tools/ct.py`, the viewer, the `ct-verify` skill and your own scripts. It lives in three places with the same layout: `CheckThatDB.global.runs` in the saved variables, the string `/ct export` makes, and `evidence/runs/<id>/r<revision>.json` after `ct.py collect`. `schema/run-results.schema.json` describes it. How the keys behave is in [Features](features.md).

Current: **ct 1, formatRev 5.**

## Two version numbers

| Key | Meaning | Rises when |
| --- | --- | --- |
| `ct` | The **major** version of the record. | A change breaks a reader: a key is removed or renamed, a key means something else, or a closed list of values (a verdict, a result) gets a new value. |
| `formatRev` | The **revision** inside a major. | Every additive change: a new optional key. |

Other stamps:

- `formatRev` on a run is the newest revision that wrote it. It only goes up: an older CheckThat that changes the run does not lower it.
- `formatRev` on an attempt is the revision it was finished in. A run can hold attempts from several versions, because a newer CheckThat can continue a run an older one started.
- `writerVersion` is the CheckThat version (the TOC `Version`) that last changed the run. It is missing when the client could not say.
- `targetVersion` is the TOC `Version` of the addon the plan tests, read when the run starts. It is missing when that addon has no version or the client could not say, and it is never the text "unknown". It is not `writerVersion`, which names CheckThat.
- `revision` is not a version of the format. It counts the changes to one run, so a copy collected earlier can be told from a later one.

## Rules for a tool that reads a run

1. **Refuse a higher `ct`, and a `ct` that is not a whole number** (`2.0` is 2, `"2"` and `1.5` are refused). An absent `ct` is a run from before it was kept: read it. Name the file and the number, and say the tool needs updating. Do this before you read any other key: a new major may have changed them. `ct.py` does so and `status` shows why.
2. **Accept a higher `formatRev`.** It only adds optional keys. Ignore the keys you do not know.
3. **A missing key means unknown.** Never read it as zero, false or empty. A run saved before 0.15.0 has no `formatRev`: do not invent one. A key that is there tells you at least what that revision had.
4. **Do not use the stamp as proof of a key.** An attempt can lose text to the size budget (`trimmed`), and a normalized older run gets `categories`. Test for the key you need.
5. **Write nothing back into a collected run.**

## Rules for a change to the format

- **Additive** (a new optional key): raise `Run.FORMAT_REV` in `CheckThat/Model/Run.lua`, add a row to the table below, add the key to the schema, document it in [Features](features.md), and keep every reader tolerant of its absence. `tools/test_ct.py` fails when this page and the code disagree.
- **Breaking:** raise `Run.MAJOR` and `SUPPORTED_MAJOR` in `tools/ct.py` only when there is no other way. Write a migration, keep reading the old major, and say so in the changelog. A CheckThat that knows only an older major keeps such a run aside and untouched (see below).

## What CheckThat does with a run from a newer major

A run with a higher `ct`, or one whose `ct` is not a whole number, moves out of `runs` into `CheckThatDB.global.future` when the addon loads (for example after you go back to an older CheckThat). It is never counted, shown, resumed, pruned or changed. The plan it names stays; when it names none, the plans stored at that moment stay, and plans imported later are pruned as usual. A new run never takes its id, and it never moves back over a readable run with the same id. A chat line says how many there are. It moves back when a CheckThat that reads its major loads it.

`ct.py collect` stores nothing of it and writes `refused.json` in the evidence folder. `status` lists the refusal and `report` warns. `report --strict` fails until a later `collect` stores a revision of that run at least as new as the refused one.

## Revisions

A run saved before 0.15.0 has no stamp. The first column says what a reader can expect in a run of that age; it is not written into old runs.

| formatRev | Since | Adds |
| --- | --- | --- |
| 5 | 0.21.0 | `since` on a check that did not pass: `run` when it read the lines after the run started (a plan's `scope: run`); `scope` is then absent. A run also saves `snapshots`, the log positions at its start, in the saved variables only: the results string and a finished run leave them out. |
| 4 | 0.20.1 | `macroStale` on a step record: how many times the CT macro ran while the card showed another step. Absent means none. |
| 3 | 0.19.0 | `targetVersion` on a run: the TOC version of the addon under test (the plan's addon) when the run started. Absent when the client could not say. |
| 2 | 0.17.0 | `reopened` on a step record: true after Undo or a rerun reopened a step that had a result. |
| 1 | 0.15.0 | `formatRev` and `writerVersion` on a run, `formatRev` on a finished attempt. |
| (no stamp) | 0.14.0 | On a check that did not pass: `kind`, `scope`, `source`, `label`, `rule`, `shape`, `window`, `matched`, `hits`, `stoppedAt`, `observed`, `trimmed`. |
| (no stamp) | 0.13.0 | `excerpt` on a failed or unverified attempt. |
| (no stamp) | 0.10.0 | `categories`, `cat` and `selected`. An older run gets them when it is loaded. |
| (no stamp) | before | `kind`, `ct`, `runId`, `revision`, `addon`, `planDigest`, `planTitle`, `client`, `build`, `character`, `started`, `updated`, `order`, `steps`, and for each attempt `n`, `started`, `finished`, `verdict`, `claimed`, `by`, `note`, `evidence`, `outcomes` (`result`, `why`, `diagnostic`). |

The record also holds `current` (the step the card showed, which browsing moves without a new revision, so a tool must not use it to compare revisions), `history` (step ids in the order their results were recorded) and, on an attempt, `build`. They were always written and are in the schema now. `tools/test_ct.py` fails when the addon writes a key the schema does not name.

## Other versions

- **Plans** have their own `ct` (`CheckThat/Model/Plan.lua`). A plan with another value is rejected.
- **The export string** starts `!CT1!`. The number is the envelope (checksum, compression), not the run. The addon imports plans only.
- **The facts API** has `CheckThat.API_VERSION`. It only grows.
- **Debug log lines** are not a contract. Read a result from the run, not from the log.
