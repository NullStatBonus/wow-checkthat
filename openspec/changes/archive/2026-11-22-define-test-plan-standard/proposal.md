# Proposal

## Why

KeepThat, DontDoThat and ClosestVendor each carry a long free-form `docs/test-plan.md` (about 1,750 lines, 470 checklist items) for checks that need a live client. Testers read prose, interpret it, and paste logs by hand. Nothing is machine-readable, so neither an addon nor Claude can guide, verify or aggregate runs. A shared, deterministic standard is needed before any runner is built.

## What Changes

- Define the **WTT test-plan format**: YAML source, JSON-Schema validated, with stable step IDs, typed actions, expectations, assertions, requirements, and reload checkpoints.
- Define **transport**: compiled plans and results move as `!WTT1!` strings (serialize, deflate, base64, checksum) for paste import and export.
- Define **evidence**: run results plus addon debug logs persist to SavedVariables on reload; external scripts collect them into one central directory for Claude to evaluate.
- Define **runner UX and ToS rules** for the in-game addon (checklist, copyable commands, user-clicked secure buttons, no input automation).
- Build an MVP against these specs: addon `WoWTestThat/` (`/wtt`), `tools/wtt.py` compiler, validator, collector and report, and draft conversions of all three sibling plans. Codex reviewed the format specs and the addon UI.

## Capabilities

### New Capabilities
- `test-plan-format`: Deterministic step schema, validation rules, and how existing plan prose maps into it.
- `plan-transport`: Import/export string encoding, versioning, integrity and size limits.
- `run-evidence`: Result record, attempts, SavedVariables flush, log capture, and external collection scripts.
- `test-runner-ux`: In-game checklist behavior, action assistance, auto-verification and ToS-safe boundaries.

### Modified Capabilities

## Impact

New repo `wow-testthat` only. Sibling addons are read, never changed; their existing debug logs are the evidence source. Bundles LibStub and LibDeflate. Follow-up: promote diagnostic assertions in converted plans to required, and first in-game smoke test.
