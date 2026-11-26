# Design

## Context

Runs live in `App.db.runs`. `App.db.currentByChar[char]` names the character's open run. A run stops being the open run in four places in `CheckThat/Model/App.lua`: `App.End` (also used by `App.ClearPlan`), `App.Start`, `App.OpenRun` and `App.DeleteRun`. `Run.End` only sets `endedAt`. No path finishes a run on its own, so the issue's reason `finished` has no source. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- One registry for run callbacks, next to `Entries`, with the same guarded, never-raise API style.
- Fire `end` and `start` from the four `App` functions, after the state change.

**Non-Goals:**
- Plan-level `setup:` and `teardown:` command lists. They run slash commands. The hook is the safer choice. Not filed as an issue: the hook may remove the need.
- Callbacks for runs of other characters.
- A version bump or changelog entry. The user holds releases.

## Decisions

- **Reasons are `ended`, `replaced`, `deleted`.** The issue also lists `finished`. Nothing finishes a run unprompted, so it would never fire. `ended` covers it. Adding `finished` later is an addition.
- **One transition, one event.** App computes the open run before and after each change. It fires `end` for the old run only when that run was open and is not the open run afterward, then `start` for the new one. This gives once-only `end` and the order end, then start, without a per-run flag.
- **Register once per addon.** A second `OnRun` replaces the first. A list would let a stale callback from a reloaded addon fire twice. Alternative: a list with removal. Rejected as more API for no known need.
- **Catch-up `start` at registration.** CheckThat loads before addons, and an open run survives a reload. Without it, an addon never learns about a run that began before it registered. `ActiveRun` stays for the case where no run is open.
- **`API_VERSION` 3.** `Facts.API()` already holds the version. The new names only add to it.
- **Errors.** A callback error goes to the debug log always. It also goes to `ns.Errors` with the addon in brackets, but that list takes errors only while a run is open, so an error raised on `end` reaches the log only.
- **Combat.** CheckThat does not delay the call. An addon that must avoid protected work in combat checks it itself.

## Risks / Trade-offs

- [A callback takes long or errors] → `pcall` isolates it. CheckThat does not time it.
- [`start` after reload may repeat] → Documented. A start handler must be safe to run twice.
- [A run replaced while open can later resume] → It gets a new `start`. That matches the transition rule.

## Migration Plan

None. No saved variable changes. Older addons ignore the new names.
