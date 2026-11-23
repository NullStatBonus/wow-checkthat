# Design

## Context

See proposal.md. `Model/` already gets `Adapter.Env()` and has no bare game globals. Only `UI/Card.lua` and `Debug/Export.lua` build frames outside the adapter. Siblings do the same; they route only hidden helper frames and data-returning services (scan tooltips, dropdown menus) through their adapters.

## Goals / Non-Goals

**Goals:**
- Make the written rule match the code and the sibling addons.
- Enforce the rule with a test so it stays true.

**Non-Goals:**
- A frame factory in the adapter.
- A guarded `GetEffectiveScale` helper. No sibling wraps scale arithmetic. Open a GitHub issue only if the Run button position proves fragile.

## Decisions

- **Carve-out, not wrapper.** `CreateFrame` returning nil leaves the caller nothing to do, so a guard hides the failure instead of handling it. Alternative: typed adapter helpers (frame, scale, bounds). Rejected: large diff in a 611-line file, no robustness gain.
- **Test the rule.** `tests/test_layers.lua` scans `Model/`, `Options/` and `Core/` (excluding `Adapter.lua`) for bare game globals, ignoring `env.X` field reads and comments. Prove it fails by adding a bare `CreateFrame` to a Model file, then remove it.
- **Keep the list short.** Check frame and client globals (`CreateFrame`, `UIParent`, `C_*`, `InCombatLockdown`, `GetTime`, `hooksecurefunc`). Do not try to list every game function.

## Risks / Trade-offs

- [Scan misses a game function not on the list] → Accept. The list targets the common ones; the adapter convention still applies in review.
- [Scan flags a comment or string] → Strip comments and ignore `.`-prefixed field access.
