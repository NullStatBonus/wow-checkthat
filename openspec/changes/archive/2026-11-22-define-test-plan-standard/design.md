## Context

Plans today are prose with `Check:` (player-visible) and `Log:` (reviewer) lines. Siblings already emit debug logs to their SavedVariables and use `/xx debug on` then `/reload`. Codex reviewed the approach and flagged: false evidence from stale or conditional logs, WTT covering the thing under test, SavedVariables only flushing on reload, imported-data trust, and a legacy bug (ClosestVendor `/cvn test sell` expects a log line it does not emit).

## Goals / Non-Goals

**Goals:** deterministic format; paste import/export; Claude-readable evidence; ToS-safe guidance; a working MVP of runner, compiler, collector and a draft conversion of all three plans.
**Non-Goals:** input automation; screenshots as assertions; Retail; hand-promoting converted diagnostic assertions to required ones (per-addon follow-up); an in-game smoke test (needs a live client; first manual run of the runner is the next step).

## Decisions

- **YAML source + JSON Schema**, compiled to canonical JSON. YAML gives comments, multi-line text and clean diffs; JSON Schema gives validation that both AI and scripts can run. Canonical JSON is the digest input.
- **Transport `!WTT1!`**: canonical JSON, raw deflate (LibDeflate in game, zlib in Python), base64, Adler-32. Chosen over uuencode (no compression, poor chat paste) and LibSerialize (a plain JSON codec is easier for Claude and scripts to read). Encoded size is capped at 120,000 characters; LibDeflate cannot cap inflate size, so this cap bounds a paste bomb.
- **Typed closed vocab** for actions, probes and requirements. Slash and macro allow lists ship in the runner, per addon, never in the plan (Codex review: a plan must not approve its own macros). Imported data is never executed.
- **Verdict model**: a claimed pass records pass only with all required assertions matched; contradiction fails; missing evidence is unverified. Diagnostic assertions never gate, so converted plans start safe and a human promotes them. A log match cannot certify color, sound, or click-through, so those keep `player`. Reviewer-only checks keep their text in `reviewer`.
- **Flow**: linear; pass/skip advance after cleanup; fail stays for retry with fresh attempt.
- **Evidence path**: SavedVariables on each verdict, plus export string for ad-hoc paste, plus collector script into a central directory.
- **Clients**: Classic Era and WoW Forever/Camelot, selected by API presence checks, not by client name where possible.
- **ToS**: all protected actions need user click or keypress; no unattended automation.

## Risks / Trade-offs

- Log-line fragility → assertions scoped to attempt window, normalized messages, diagnostic-only flag.
- Lost results on crash → write at every verdict, show "in memory" label.
- Plan size caps → reject oversized imports rather than truncate.

## Open Questions

- Exact macro creation limits per client (verify in game).
- Resolved: no LibSerialize; canonical JSON.
- Needs a live client: macro slot limits, SecureActionButton behavior on Forever, and the card layout.
- ClosestVendor plan expects `reminder: test` from `/cvn test sell`, which Codex found it does not emit; fix when promoting its assertions.
