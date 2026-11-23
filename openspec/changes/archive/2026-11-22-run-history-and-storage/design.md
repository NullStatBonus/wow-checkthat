# Design

## Context

See proposal.md. Observed in code:
- `Evidence.Snapshot(plan, env)` copies every log in `plan.logs`. `Run.Begin` calls it with no step.
- `Evidence.NewLines(snapshot, current)` needs only `#snapshot` and the last `min(12, n)` lines. With no snapshot it returns the whole current log.
- `App.db.planStore[digest]` is written on import and on Start. Nothing deletes it. `App.ClearPlan` keeps the stored copy on purpose, so an ended run keeps its results screen.
- `App.db.runs` is keyed by runId. `App.db.currentByChar` names the open run per character.

## Goals / Non-Goals

**Goals:**
- Smaller attempts and a bounded saved-variable size.
- A player can reopen, export and delete older runs.

**Non-Goals:**
- Comparing runs, or merging them.
- Sharing runs between characters.
- Moving data out of saved variables.

## Decisions

1. **Position record.** A snapshot becomes `{ n = <length>, tail = { last 12 lines } }`. `NewLines` accepts both this and the old full array (a table with `unavailable` stays as is). Alternative: keep the full array and cap it. Rejected: the tail is all `NewLines` reads.
2. **Which sources.** `Evidence.Snapshot(plan, env, step)` collects `a.source` from the step's assertions of kind log or log-sequence with scope not "session", including diagnostic ones (they are checked at the verdict). With no step it snapshots nothing.
3. **Missing position is unverified.** `CheckLog` and `CheckSequence` return unverified with "log position missing" when an attempt-scoped assertion has a snapshots table but no entry for its source. `NewLines(nil, current)` keeps returning the whole log only for the case with no attempt (Preview of a step with no open attempt). This closes the hole where dropping a source would turn into a false pass.
4. **Plan pruning.** One function `App.PrunePlans()`: keep a digest if a run names it (`run.planDigest`), `db.plans[*].digest` names it, or `ui.recent` names it. Called at the end of `ImportPlan`, `ClearPlan` and run delete. Cost is small: tables of a few entries.
5. **Run limit.** A saved setting in the account-wide `global` table (runs are account-wide and never copied between profiles) with a default of 20 and a range of 5 to 100, set on Advanced (not a `/ct set` key), enforced in `App.Start` and on delete. Current runs of every character are never removed. Alternative: prune by age. Rejected: players with one run a month would lose data for no gain.
6. **Runs list.** A group on the Home page built from `App.Runs()`, which returns rows newest first. AceConfig cannot grow rows at run time, so the list is a `select` of runs (date, plan, character, counts) with three `execute` buttons: Open, Export, Delete. This is the pattern the Plans page already uses to remove a plan. Delete uses the AceConfig `confirm` text. Standard controls, so no custom control and no fallback. Open makes the run the one the card shows for this character (`currentByChar`), so the existing results screen and read-only rules apply with no new card state. A run that has not ended and belongs to another character cannot be opened, since runs are bound to their character (see run-evidence "Runs are bound to their plan and character"); it can still be exported or deleted. Opening a run never ends or deletes the run it replaces; that run stays in the list.

## Risks / Trade-offs

- [A step edited to add a log assertion after a run started has no position] → unverified with a clear note, never a false pass. Matches decision 3.
- [Old saved runs mix both snapshot shapes] → `NewLines` handles both; covered by a test.
- [Pruning removes a plan another character's ended run needs] → the rule keeps every plan named by any stored run, whatever character.
- [A long dropdown at limit 100] → rows are newest first and one line each.
- [Opening an old run takes the card's place from an unfinished run of the same character] → the unfinished run stays in the list and Open brings it back; the confirm text on Open says so.

## Migration Plan

No data migration. New attempts write the new shape. Old runs keep their old snapshots until pruned. Rollback: an older addon version reads `tail` snapshots as non-arrays and shows unverified for open attempts only; ended runs are unaffected.
