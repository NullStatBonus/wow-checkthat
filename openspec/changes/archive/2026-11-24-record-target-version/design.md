## Context

`Adapter.Version()` reads CheckThat's own TOC version. `Run.New` is in `Model/`, which has no game globals, so the value comes in through `ctx`.

## Goals / Non-Goals

**Goals:**
- Record the tested addon's version once, when the run starts.
- Let `diff` and `trend` use it.

**Non-Goals:**
- The minor versions of libraries the tested addon embeds: https://github.com/NullStatBonus/wow-checkthat/issues/114.
- Updating `targetVersion` when a run continues after the addon updated. The value is the version the run started with.
- Changing the meaning of `trend --by version` (the CheckThat version).

## Decisions

1. **Adapter.** `Adapter.AddonVersion(name)` reads `C_AddOns.GetAddOnMetadata` or `GetAddOnMetadata` in `pcall`. It returns nil for a bad name, a missing function, an error, an empty or non-text value and "unknown".
2. **Where it is read.** `App.Start` passes `ctx.targetVersion`. `Run.New` stores it only for a non-empty text that is not "unknown".
3. **Format.** An additive key: `FORMAT_REV` 3, a schema property, a row in `docs/results-format.md`. Readers treat a missing key as unknown.
4. **Tools.** `run_head` and `run_model` carry it. The diff header prints "tested addon X" or "?". `--by target` is new, so `--by version` keeps its meaning.
