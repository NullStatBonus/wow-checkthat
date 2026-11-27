# Design

## Context

The card is built in `CheckThat/UI/Card.lua`:
- `build()` at line 182.
- `refreshCard()` at line 629. It draws the banner at 763, the reloaded line at 779, the context lines at 783 to 792, the Setup, Do and Expect rows at 793 to 816, the checks at 818, and the note at 853 to 858.
- `Card.AutoSettle` at 936 moves on after an automatic result.

Requirements already exist: `step.requires` names `plan.requirements` entries (`text`, a state `probe`). `Run.Blocked` (Run.lua:327) lists the unmet ones as a "Blocked:" line.

The design was reviewed with Codex and with a published mockup (`card-checklist.html`). The owner chose the following:
- Checkboxes for player actions only. The verified checks list stays as it is.
- No Pass gate.
- A per-step `async`.
- All five removals.
- A 3 second fade after an automatic result.
- A heavier title.

## Goals / Non-Goals

**Goals:** the decisions above, all additive. Old plans keep their digest and their result.

**Non-Goals:**
- Sounds (#229).
- An `entry` condition in a requirement. Entry calls on player steps are #225; the issue is commented when this change ships.
- Ticks as evidence.
- A Pass gate.

## Decisions

- **List fields.** `action.text` and `expect` accept a string or a list of 2 to 6 strings. Plan.lua and `ct validate` check each item as text (Markdown, colour codes, slash command warnings). Anything that reads `action.text` (`ct.py` wording warnings, `lines`, `from-md`, the macro hint) joins a list with spaces when it needs one string.
- **Checkbox rows.** A pool of up to six rows, each a `CheckButton` from `UICheckButtonTemplate` (the start screen already uses it, `makePick`, line 610) and a label FontString. On reuse, the checked state, the label and the attempt key are reset. A missing template gives a Button with "[ ]" text. Ticks go through `App.Tick(i, on)` to `Run.Tick`, which writes `attempt.ticks[i] = now` or nil and bumps the revision.
- **Expect list.** Plain FontStrings with a grey bullet, one per item.
- **Heading in place of the banner.** It uses the same strings. `L["CheckThat checks"]` and `L["CheckThat checks and records the result"]` sit above `card.checks`. The `YOU CONFIRM` strings are removed from the locale.
- **Setup fold.**
  - A Button with an arrow and the first line of the setup, then the full setup, preamble and section intro.
  - It opens by itself on the first visit of a step in this run, kept in `App.db.ui.setupSeen` (`{ run = runId, ids = {} }`, reset for a new run so it never grows).
  - "Blocked:" lines stay outside the fold.
- **Add note.** A small text button. A click shows the existing EditBox in its place and gives it focus. An attempt with a note shows the box.
- **Title.** A font object `CheckThatCardTitle` from `GameFontHighlightLarge`'s file, one size larger, with an `OUTLINE` flag; WoW fonts have no bold weight. Falls back to `GameFontHighlightLarge` when `CreateFont` is missing. Checked in game with a screenshot.
- **Fade after an automatic result.**
  - `Card.AutoSettle` records first, as today, so nothing about the result waits on the UI.
  - It then sets `card.hold = { stepId, until = now + 3 }`. While the hold is on, `refreshCard` draws the recorded step read-only with "Recorded: Pass (recorded by CheckThat)".
  - Timers (`A.After`) step the card's alpha from 1 down to 0.4 in six steps over the 3 s, then the next step draws at full alpha. Without timers there is no hold. This avoids the AnimationGroup API differences between clients. The hold state is a local in `Card.lua`, not a field on the frame.
  - A card press or result key ends the hold. Navigation then applies; a result press is dropped with one chat line, so a key meant for the passed step cannot judge the next one.
  - With the card hidden or collapsed, there is no hold.
  - The secure Run button stays hidden during the hold (out of combat), because the recorded step shows no commands.
- **Inapplicable requirements.**
  - `Adapter.ClassToken()` reads `UnitClass("player")`.
  - `Adapter.Professions()` reads skill lines: `GetNumSkillLines` and `GetSkillLineInfo` on Classic Era. Code checks which functions exist, never the client name.
  - `Run.Blocked` lists only blocking requirements; `Run.Unmet` returns the text of the first unmet `inapplicable` one. `App.Begin` checks it before it opens an attempt and calls `Run.MarkInapplicable`, which records no attempt (an attempt verdict `inapplicable` would be a new value in a closed list), sets the step's verdict to `inapplicable` with the text in `unmet`, and moves on.
  - Unknown data (nil) means the requirement holds.
- **Async steps.**
  - `App.Start` and `App.Rerun` call `Run.JudgeAtStart`. It builds an attempt `{ started = now, at = "start" }` with no snapshots, so every source reads as the whole retained log, and judges it with `Run.Verdict(..., holdUnlessMet)`. A step with an unmet requirement is left for its turn.
  - On a pass it records the verdict with claim `auto`. On anything else it drops the attempt.
  - It opens no attempt for the current step and calls no entry.
  - `Run.NextPending` already skips resolved steps.
- **Format.** `Run.FORMAT_REV` +1 (after run-scope's 5, this is 6). New optional keys: `attempt.ticks` and `attempt.at`. Readers ignore unknown keys. `docs/results-format.md` gets a row for it.

## Risks / Trade-offs

- A fade can hide a quick second result. A press ends it.
- Profession names are localized. The plan is written for one locale already.
- The heavier title must still fit two lines at 380 wide. `fit()` clips it, and the collapsed strip keeps one line.
- Removing the gold banner changes `DESIGN.md` §3. Its text is updated in the same change.
