# Design

## Context

`tools/entry_runner.lua` takes a decoded spec table: `toc`, `mocks`, `mockAfterLoad`, `steps`. See proposal.md. `Plan.Validate` in the game ignores unknown fields, and compile already goes through `merge_sections`.

## Goals / Non-Goals

**Goals:**
- Plan authors write the runner's spec inside the plan.
- The game never sees it.

**Non-Goals:**
- Per-category setup with restore after each step (#107).
- `CheckThat.Entry` in the game (#97), the taint probe (#98), the login self-check (#99).
- Running the block from `ct.py replay`. It is a separate command, because it needs the addon's files and the saved-variables replay does not.

## Decisions

- **Same shape as the runner's spec.** The block is passed on as is, so there is no second format to drift. Step `label` (optional) names the JUnit case.
- **Strip in `merge_sections`.** One place covers compile and the digest.
- **Allow list in the runner.** A plan is data from an author; the runner owns what may be replaced. Start with `GetItemInfo`, `GetItemCount`, `C_Item.GetItemCount`, `GetMoney`, `GetNumFreeSlots`-style bag calls, `GetTime` and `UnitName`; add a name with its own test.
- **`toc` is relative to the plan file**, since addons live in sibling repositories.
- **Separate command.** `ct.py offline` runs luajit with the repository root as the working folder.

## Risks / Trade-offs

- An offline pass does not prove the game agrees: taint is unmeasured (#98). The docs say so.
- Allow list too small at first; extending it is one line and a test.
