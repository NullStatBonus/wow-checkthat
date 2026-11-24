# Design

## Context

Codex reviewed the first draft and the code. It chose the names and the rollout, and it asked for the guard to sit before any code can reach a run it cannot read.

## Goals / Non-Goals

**Goals:**
- A format that can keep changing: readers know what a stamp means and what to do with a higher one.
- A run from a newer major version survives a trip through an older CheckThat.

**Non-Goals:**
- Reading a newer major in this version. It is refused, not guessed at.
- A backfilled revision number for old runs. A missing stamp stays "unknown". The page lists what each release added.
- Versioning the debug log lines. They are not a contract.

## Decisions

1. **Two integers.** `ct` is the major (refuse a higher one). `formatRev` is the minor (accept a higher one, ignore unknown keys). Names do not clash with `revision` (a change counter) or `addon` (the addon under test).
2. **Stamp at the commit.** `Touch` and `Normalize` stamp the run: `formatRev` is the maximum, `writerVersion` is the last writer (omitted when unknown). `Verdict` stamps the finished attempt once, because an attempt can open before an upgrade and finish after.
3. **Keep a newer run aside.** At load, a run with a higher `ct` moves to `global.future`, the same table. Nothing else in the addon reads `future`, so nothing can count, prune, normalize or change it. `PrunePlans` keeps its plan, or keeps every plan when the run has no digest. It moves back when `ct` no longer exceeds `Run.MAJOR`.
4. **First stamp is 1.** No exact revision numbers are given to unstamped runs.
5. **The tools refuse before they read.** `check_major` runs before the shape check in `read_run` and in `write_revision`. `collect` also reads `future` so the refusal is named. `latest_runs` can say which newer revision it skipped, and `report` warns and `--strict` fails.
5a. **A refusal is remembered.** `collect` writes `refused.json`; `report --strict` fails until a revision at least as new as the refused one is stored. A present `ct` must be a whole number from 1 (`2.0` is 2, `"2"` is refused) and an absent one is a legacy run.
5b. **No clobbering.** A run set aside keeps its id (a new run never takes it, a restore never overwrites a readable run), `collect` keeps the `runs` and `future` tables apart, and the plans stored when a run that names none was set aside stay (later ones are pruned).
6. **One page of truth.** `docs/results-format.md` holds the table, and a test compares it with `Run.MAJOR`, `Run.FORMAT_REV` and `SUPPORTED_MAJOR`.

## Risks / Trade-offs

- [A player goes back and forth between versions] → the run moves aside and back with the same table.
- [An old tool reads a newer minor] → it ignores unknown keys, as the rules say.
