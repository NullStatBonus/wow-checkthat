# Design

## Context

`Card.RunMenu` builds the title menu with one item. `A.ContextMenu` falls back to `Card.ConfirmEnd` when no menu API exists. `Card.ImportPrompt` opens the import box. `App.db.plans[addon]` holds the loaded plan, `planStore[digest]` keeps the exact plan a run started with, and `ui.recent` lists recent plans. An ended run reads its plan from `planStore`.

The header label "CheckThat / Run" is a plain font string with a hit button and a small arrow. In the collapsed card the step counter and hidden prev/next buttons share the header row. In `Card.Refresh` the collapsed card sets `card.title` to 256 wide, but the title uses a large font with wrapping on. A long word, or a long step title, can still run past the edge. The root cause needs one in-game reproduction first (see Risks).

## Goals / Non-Goals

**Goals:**
- Titles never leave the card.
- Import and Clear plan are one click from the Run menu, and the menu looks like a menu.
- The collapsed card and the start and ended screens lay out cleanly at their widths.

**Non-Goals:**
- No `/ct clear` command.
- No start-screen hierarchy rework (plan title as heading, step count under it). Tracked as a separate issue.
- No deletion of stored plans or runs. Results stay exportable.
- No change to the no-menu fallback beyond End run.

## Decisions

- **Fit text.** Collapsed: `card.title` is one line (word wrap off, fixed width) so the client adds an ellipsis, with a tooltip of the full title. Expanded: two lines at most. The height clamp alone limits the frame, not the text, so the line limit is the fix. Alternative: shrink the font. Rejected: it hurts readability.
- **Run control.** Replace the label and tiny arrow with a button-like control "Run" plus the stock dropdown arrow and a hover highlight, as the bundled AceGUI dropdown does. Check Blizzard UI and popular addons for the same pattern before building. Keep the whole control as the hit area.
- **Mini header.** Anchor the counter to the left of the collapse button. Hide prev/next without reserving their space.
- **Start screen.** Width is 380 whenever the start screen shows, also over a collapsed run (the old code narrowed the card to 280 while `card.context` stayed 356 wide, so the plan title ran out). The first visible button anchors at the left inset.
- **Ended screen.** Export results stays first. If `App.db.plans` holds no plan, the second button is "Import a plan" (calls `Card.ImportPrompt`) instead of Main window.
- **Clear plan = End run + forget plan.** The confirmation names the plan, so the combined effect is clear without a longer menu label. `App.ClearPlan(runId)` calls `App.End`, then removes `db.plans[run.addon]`, `pendingStart`, `lastImport` and the matching `recent` entry. It keeps `planStore` and the run, so the ended screen and export still work. Alternative: forget the plan and leave the run active. Rejected: the card shows the run anyway, so the plan would look unchanged.
- **Menu items.** `{ Import... }, { End run... }, { Clear plan... }` in one list. Import calls `Card.ImportPrompt`. Clear plan uses a new `Card.ConfirmClear` with the same stale-run check as `ConfirmEnd`.
- **Where the menu shows.** Unchanged: while a run is active and no new plan waits to start.

- **No Reload button.** `card.reload` and its layout code go. `App.Copyables` and `App.MacroText` already add `/reload` for a `reload` action, so the Run button covers those steps. The `reload: after_action` hint, a share-point chat line and the results screen text name `/reload`. The `/ct reload` command stays. Sample plan text that said "Press Reload on the card" changes.

## Risks / Trade-offs

- [A step with `reload: after_action` but no listed command has no Run button] → The hint tells the player to type `/reload`.

- [Hover tooltip and arrow textures are client calls] → Keep them in `UI/`, guarded; the plain label remains where a texture is missing.
- [Harness has no text measurement] → Tests assert the width, line limit and wrap settings, not pixels. The manual check covers the look.
- [Root cause unconfirmed] → First task reproduces with a long title and records which font string overflows; fix targets that one and any sibling.
- [Clear plan removes a recent entry another run still uses] → Only the recent list entry goes. `planStore` stays, so other runs are safe.
