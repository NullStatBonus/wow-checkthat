# Proposal

## Why

Converted KeepThat steps carry only diagnostic assertions, so a claimed pass is never backed by evidence. The user chose KeepThat first. Codex also found wrong-client steps stay eligible and some conversions point the wrong way.

## What Changes

- Promote unconditional KeepThat `Log:` checks to required assertions, each checked against KeepThat source or its saved log: `[blizzard]`/`[merchant] hooked`, the Auctionator estimate line, recipe status, skills line, Profession Journal off-then-on sequence.
- Keep conditional or addon-dependent checks reviewer-only or diagnostic (bag addon choice, bank/mail close race, report contents).
- Tag steps that apply to one client (§4.4, §9.1, §9.2).
- Add a self-test plan for WTT itself so the first live run needs no sibling addon.

## Capabilities

### New Capabilities

### Modified Capabilities
- `test-plan-format`: rule for which converted checks may be required

## Impact

`plans/keepthat.yaml`, new `plans/selftest.yaml`, schema addon enum, Lua `Plan.SLASH`, tests.
