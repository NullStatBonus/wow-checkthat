# Design

## Context

Attempt positions already exist: `Evidence.Snapshot(plan, env, step)` (`CheckThat/Model/Evidence.lua:489`) saves `{ n, tail }` for each source an attempt-scoped assertion of the step reads, and `window()` (line 102) turns it into the new lines with `Evidence.NewLines`. The errors source (`CheckThatDB.global.errors`) is a bounded strings log, read the same way.

## Goals / Non-Goals

**Goals:** `scope: run` for log, log-sequence and fact assertions; correct across `/reload`; the missing OnRun changelog line.

**Non-Goals:** clearing or marking the errors list at run start (it is shared with other runs and must not lose data); a run scope for state probes (they read the present state).

## Decisions

- **Save positions at run start, not a timestamp.** Log lines carry no reliable time, and the attempt path already handles rolled and repeated tails. `Run.New` stores `run.snapshots = Evidence.Snapshot(plan, env, nil, "run")`: the snapshot function takes a scope filter and walks every step's assertions for `scope == "run"`.
- **One window function.** `window(a, snapshots, plan, env)` gets the run's positions for a `run`-scoped assertion. Every place that tests `a.scope ~= "session"` (Evidence.lua lines 86, 124, 126, 187, 227, 326, 408, 410, 473, 493) is reviewed: a `run` scope behaves as `attempt` with other positions.
- **Saved check detail.** `scope` on a saved outcome is a closed list (`attempt`, `session`); a new value would be a break under the results-format rules. A run-scoped check saves `since: "run"` and no `scope` instead, so an older `ct.py` still reads the outcome.
- **Old runs.** A run without `snapshots` gives "run has no start position" and unverified. `Run.FORMAT_REV` goes from 4 to 5 for the new optional `run.snapshots`.
- **Rerun and Undo** keep the run's positions: the run did not restart.
- **Tools.** `ct.py` accepts `scope: run` in plans through the schema, accepts `since` on outcomes, prints "since the run started" next to the source, and drops `run.snapshots` from the collected form as `/ct export` does. `replay_plan.lua` treats `run` as "lines since the plan started".

## Risks / Trade-offs

- A run that lasts longer than the log's capacity loses its start position. The check is then unverified, as a long attempt is today (#158).
