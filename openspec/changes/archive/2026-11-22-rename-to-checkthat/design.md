# Design

## Context

See proposal.md for why. The old name is spread over three kinds of places: product text (title, settings window, card, docs), identifiers that depend on the folder name (TOC file names, AceAddon name, `Interface\\AddOns\\TestThat\\Media\\icon.tga`, packaging paths, check scripts, test paths) and data names (`TestThatDB`, `TestThat.lua` in WTF, the `addon: TestThat` entry of plans). A fourth group, the `WTT` plan-format names, is not about the addon and stays.

## Goals / Non-Goals

**Goals:**
- Every name in the repository and in the game says CheckThat, except history (archived changes, past changelog entries) and the plan-format names.
- The sibling pattern holds: a short command (`/ct`) and a long one (`/checkthat`).

**Non-Goals:**
- Compatibility with the old name: no saved-data copy, no `/wtt` alias, no legacy plan key. Nobody has installed the addon, so there is nothing to keep working. After the first release a rename would need them.
- Renaming the plan format (`!WTT1!`, `wtt: 1`, `.wtt`, `[wtt]` log lines, `WTT` macro, `wtt.py`, the `wtt-test-plan` skill, `Copy-WttEvidence`). The decision keeps them: sibling plans and installed skills depend on them.
- Renaming archived OpenSpec changes or past changelog entries. They record what was true.
- Renaming the GitHub repository, the CurseForge project or the Wago project. Those are manual steps; the TOC keeps its project IDs.

## Decisions

**1. A mechanical rename.** Replace `TestThat` with `CheckThat`, `TESTTHAT` with `CHECKTHAT`, `testthat` with `checkthat`, `TestThatDB` with `CheckThatDB`, and the slash command `/wtt` with `/ct`, in every tracked text file except the archive, `CHANGELOG.md` history, the vendored libraries and the main specs (the specs change through the deltas). The command pattern does not match `tools/wtt.py` or other paths. Alternative: edit file by file. Rejected: 49 files, and a missed name is a bug.

**2. The folder moves with `git mv`.** `TestThat/` becomes `CheckThat/` and the TOC files become `CheckThat_Vanilla.toc` and `CheckThat_Camelot.toc`, because the game ties the TOC name to the folder name. AceAddon takes its name from the folder, so the addon name changes by itself.

**3. Two commands, one handler.** `Slash.Register` registers `ct` and `checkthat` with the same function. The runner's allow list, the harvest tool's mirror and the plans use both.

**4. The schema and tools follow.** `Plan.SLASH.CheckThat` and `tools/wtt.py` list `/ct` and `/checkthat`. The schema's addon list names `CheckThat`. `collect` reads `CheckThat.lua`.

## Risks / Trade-offs

- [A missed old name shows to players] → a search for the old name outside history must come back empty, and a reviewer sweeps the docs.
- [`/ct` clashes with another addon] → `/checkthat` remains.
- [The CurseForge project keeps its old slug] → manual, outside the code; the TOC IDs stay.
- [Old evidence folders keep `TestThat.lua` files] → they are local data, not read by the new tools; copy them by hand if needed.

## Migration Plan

Release 0.5.0 as the first release under the new name. Rename the GitHub repository to `wow-checkthat` by hand after the commit.

## Open Questions

None. The repository name is assumed to be `wow-checkthat`, matching `wow-keepthat`; GitHub redirects the old URL.
