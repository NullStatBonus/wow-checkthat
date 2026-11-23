# Design

## Context

See proposal.md for motivation. Today:

- `Card.tick` calls `Card.UpdateChecks` every 0.5 s while the card is shown. It runs `Run.Preview`, which reads each required assertion through `Evidence.Check` and shows met, waiting, bad or later. The card says "All checks detected. Press Pass."
- `Run.Verdict` already gates a pass or partial claim: contradicting evidence gives fail, missing evidence gives unverified, all met gives pass with evidence matched. A fail claim is not gated.
- An attempt stores `started` (wall clock) and its log snapshots, and survives `/reload`.
- `wait-event` is in the schema and validator, but nothing in the runner uses it (#6).
- The player's rule: no macros, no outside automation, nothing that could breach the game's terms. This change only reads state the addon already reads.

## Goals / Non-Goals

**Goals:**
- The runner records a pass, fail or unverified result from evidence alone for steps that opt in.
- Reuse the existing evidence gate, so an automatic result means the same as a player's claim with the same evidence.
- Keep every result reviewable: the claim is labelled `auto`.

**Non-Goals:**
- Event-driven triggers. The runner polls on the card refresh. Registering game events for a step stays in #24.
- Settling while the card is hidden: #27.
- Any new probe, input, macro kind or slash command. `Plan.SLASH` and the probe list do not change.
- Auto-fail the moment a check reads bad. Only the timeout fails a step.
- A plan-wide or default timeout.

## Decisions

**1. Opt-in per step with `auto: true`, not inferred.** Many steps with assertions still need the player to judge the result. Inferring auto from "has required assertions" would skip that judgment. Alternative: a plan-level switch. Rejected: one plan mixes both kinds of step.

**2. Poll on the existing refresh, not game events.** Logs and probes are read through the Adapter on demand, so an event adds no information, only latency and Adapter surface. `Card.UpdateChecks` gains one call, `Run.AutoSettle(run, ctx, id)`. The model function takes `ctx.now` and the environment, so luajit tests drive it with a fake clock and log.

**3. Settle through `Run.Verdict` with a pass claim.** At "all met" the runner calls the same path as a Pass click. At the timeout it also calls it with a pass claim, and the gate turns that into fail (contradicts) or unverified (missing). No second set of rules for outcomes. `Run.Verdict` takes an optional `by` argument that stores `by = "auto"` on the attempt; `claimed` keeps the pass claim the gate saw. Alternative: a separate auto-verdict function. Rejected: it would copy the gate.

**4. Timeout counts from `attempt.started`.** It is wall clock and already saved, so a reload does not restart it. Authors must pick a timeout that covers the player's action plus the result. A step that reaches the timeout with all checks met would already have passed.

**5. Settle at most once per attempt.** Auto-unverified closes the attempt and the step stays open. The card's refresh opens the retry attempt straight away, as it does for any unverified step. `Run.Begin` marks that retry `noauto` when the attempt before it was settled by auto as unverified, so the timeout cannot loop. The player's next result, or Redo, starts a fresh attempt that can settle again. The report and card read the last finished attempt, not the open retry.

**6. Validation rules sit in `Plan.Validate`, the schema and `tools/wtt.py`.** `auto` needs `assertions` in `verify`, no `player`, at least one required assertion and no required absence assertion. `timeout` is an integer from 5 to 300 and only on an auto step. `wait-event` is valid only on an auto step. Absence assertions are excluded because they are judged only at verdict time and have no met state.

**7. `wait-event` becomes display only.** On an auto step it shows "Waiting for: <expect text>" instead of the Do row's instructions. No runner logic of its own. This closes #6 without a second mechanism.

**8. When the runner may record.** Only while the card is shown and visible (not with the game interface hidden), not while the Start screen of another plan is showing, with the card's note box passed through, and with the secure button never touched in combat (`setMacro` returns early in combat, which also fixes the same path for a player's click). The settle logic stays in `Run`; the card only calls it from its refresh loop.

**9. Two reads must agree, and a requested reload comes first.** The live check and the recording read are separate reads. `Run.Verdict` takes a hold flag so an automatic pass that finds a changed check records nothing and waits for the next refresh. Only the timeout may record fail or unverified. A step with `reload: after_action` is not settled by the all-met path until the attempt is marked reloaded. Undo counts as the player acting, so the reopened step can settle itself again.

**10. Bookkeeping, not input.** `Run.AutoSettle` and the card change only the run record, the card text and the debug log. No Adapter function that clicks, types or casts is added. A test asserts that the fake client saw no protected call during an automatic settle.

## Risks / Trade-offs

- [A badly chosen required assertion auto-passes or auto-fails a step wrongly] → the existing rule that a required check must be an unconditional line stays; the authoring skill asks for it; every result is labelled `auto` and Undo reopens the step.
- [The timeout is too short for a slow player and records a false fail] → fail needs a contradicting check, not a missing one. A step with only log lines times out to unverified, which stays open. The skill tells authors the timeout covers the player's action time.
- [A hidden card stops settling] → documented in the card text and README; #27 tracks it.
- [The wall clock can jump] → the clock is the one already used for attempts; a backward jump only delays the timeout.

## Migration Plan

Additive. Existing plans have no `auto` or `timeout` and behave as before. Imported plan strings with the new fields fail validation on an older runner, as any unknown field does. Add the version bump at archive: this is a new capability, so a minor bump.

## Open Questions

- Should an automatic pass show a short toast on the card, or only move on and mark the step? Visual detail only; start with the recorded line on the step.
