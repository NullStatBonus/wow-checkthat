## Context

KeepThat logs go to `KeepThatDB.global.log` (strings). Verified lines come from KeepThat source via grep before promotion.

## Decisions

- Session scope for startup lines (`hooked`), attempt scope for lines emitted by the step's own action.
- Self-test plan uses addon `KeepThat` slash allow list? No: add `WoWTestThat` to the schema addon enum and `Plan.SLASH` with `/wtt` so the plan can offer `/wtt debug on`. Its log source is `WoWTestThatDB.log.entries` (entries format), which the runner already writes.

## Non-Goals

- Promoting DontDoThat or ClosestVendor; running in a live client.
