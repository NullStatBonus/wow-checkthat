## Context

The review reports are in the task list. Plan validation (`Plan.lua`, the schema, `tools/ct.py`) is another change and stays untouched here.

## Goals / Non-Goals

**Goals:** show what a plan reads before a run starts; fix the reload mark; remove the smaller defects.

**Non-Goals:**
- Restricting which globals a plan may read. It would break plans that exist. The note is additive.
- Listing requirement probes. A `requires` probe reads a global but saves only whether it was met, not the value.

## Decisions

- **What counts as a read.** Each log source's `global` and each `global-value` probe's `name` in a step's assertions. Both can put content into the results string (log hits, excerpts, `observed`). A `frame-shown` probe is left out: it saves only true or false. `addon-loaded` reads no global.
- **Where to show it.** A grey small line under the step count on the start screen, the place the card already uses for the plan's status. It is plain text in the same font as the other help lines (DESIGN.md): the tester reads it before Start run, and no click is needed. A tooltip was rejected because the note must be visible without a hover. The line shows six names and then "and N more"; the debug report holds the full list as `Plan reads: <names>`.
- **Names are plan text.** They are cut to 40 characters and a `|` is doubled, so a plan cannot put a color code on the card.
- **Reload mark.** `App.OpenRecord()` returns the character's open run (with its plan saved). `App.MarkReloaded()` marks that run's open attempt and returns it; `OnEnable` prints the resume lines for it only. The status line takes the run as an argument.
- **Chat escape on the slash path only.** `Slash.Esc` wraps `CategoryLine` in the `categories` command. The Categories window and tooltips keep the raw title, because a frame shows `||` as two bars only when text is escaped.
- **Verdict words.** One sentence `Step %s%s.` stays, with each result and evidence word an `L[]` string, as `App.StateWord` does. English output is the same.
- **Packaging.** The Ace3 and LibDeflate license files ship inside `CheckThat/Libs`. `THIRD_PARTY.md` only points to them, so it and `requirements-tui.txt` go on the `.pkgmeta` ignore list. `LICENSE` and `CHANGELOG.md` still ship.
- **`Run.Undo`.** The code set `rec.verdict` from the earlier attempt and then set it to `pending` whenever it was not. The result was always `pending`. The dead computation is removed; the saved record is the same.

## Risks / Trade-offs

- A plan that reads many variables shows a long line. The cap keeps the card short.
