## Decisions

- Partial reuses the pass path in Model/Run.lua so evidence gating cannot differ.
- Button widths: Pass, Partial, Fail, Skip 56; Undo 48; Reload 66; Run 56. Command boxes 190 so box (66..256) + 8 + Run (56) ends at 320 of 380.
- Character key: UnitFullName first, then GetNormalizedRealmName, then GetRealmName; "?" only if all are empty.

## Non-Goals

- Required notes for Partial or Fail; per-step verdict sets.
