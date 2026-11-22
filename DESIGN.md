# TestThat presentation and interaction design

TestThat follows the shared presentation contract documented in KeepThat's `DESIGN.md` (v1). This file records how TestThat applies it. **Shared** means a common design vocabulary, not shared SavedVariables or a required runtime library.

## 1. Product principles

1. **Explain each decision.** State the page purpose, settings scope and next action. Keep the text short.
2. **Stay recognizably native.** Use Ace and Blizzard controls and tooltip chrome. Do not reskin the game.
3. **Keep the interface compact.** The checklist card is small, movable and collapsible. It must not cover the thing under test.
4. **Use color for meaning.** Name a result as well as coloring it. Amber means missing evidence, not an error.
5. **Preserve player choices.** Disabled controls keep their values. Switching settings scope copies nothing.
6. **Never play for the player.** Every protected action is a player click or keypress.
7. **Remain independently installable.** Missing APIs and other addons give an explained fallback, not a Lua error.

### Help text: ASD-STE100

Write help text as in KeepThat's `DESIGN.md`: one instruction per sentence, command verb first, at most 20 words per instruction, active voice, the same word for the same control, no contractions. Troubleshooting reads: **record, repeat the problem, show the report, press Ctrl+A then Ctrl+C, turn recording off.**

## 2. Settings window

AceConfig/AceGUI with a tree and a scrolling content pane.

| Element | Decision |
| --- | --- |
| Standalone initial window | 600 x 460 logical units |
| Window title | TestThat |
| Navigation | Ace tree; resizable; content scrolls |
| Sliders | 1.5 Ace control widths |
| Action buttons | Standard width; longer labels 1.5 widths |
| Booleans | Checkbox, full width |
| Body text | Full width, neutral #DDDDDD, wrapped |
| Secondary text | Grey #AAAAAA, small |

The same pages are registered in the game's Settings window.

### Pages

| Order | Page | Purpose |
| --- | --- | --- |
| 1 | Home | Current run, start a run, import a plan, export results |
| 2 | Plans | Imported plans and removal |
| 3 | Appearance | Card scale, background opacity, text opacity, lock, reset position |
| 4 | Advanced | Settings scope and debug recording and report |
| 5 | About | Name, version, purpose and commands |

Every page works when opened directly (`/wtt settings <page>`). Each page starts with a heading, a purpose of one or two short sentences, then sections per task.

### Scope

Settings use the shared Default profile. A checkbox in Advanced switches to a character profile after confirmation, copies nothing, and keeps both. Plans, runs and the log are account-wide and never copied between profiles.

## 3. The checklist card

- Importing a plan opens the window with the plan title, its step count and Start run. The import screen has a text box and a "Recent plans" dropdown (up to 8, newest first); choosing one needs no paste.
- Layout, top to bottom: header (step number, collapse, close), a 3 unit progress bar filled by resolved steps, the step title (largest text), Setup / Do / Expect in a 62 unit label column, the step's commands in read-only boxes beside Do with Run next to the first, an amber evidence line only when evidence is missing, a labelled note field, and a pinned row of Pass, Partial (mostly works), Fail, Skip and Undo (24 high; Reload joins the row only when a step asks for it). The secure button is labelled Run and sits inside the card beside the first command. After a reload a green "Reloaded" line shows under the title.
- Under the title a banner says who checks the step: green TESTTHAT CHECKS THIS STEP (the required checks are listed below Expect and tick live with the stock ReadyCheck icons) or gold YOU CONFIRM THIS STEP. < and > in the header move between steps; a finished step shows what was recorded with a Redo button.
- Fonts are stock Blizzard: GameFontHighlightLarge (title), GameFontHighlight #DDDDDD (Do, Expect), GameFontHighlightSmall #AAAAAA (header, labels, hints). Amber means missing evidence only.
- Collapsed, the card is a 280 wide strip with the step title and number. When the run is complete it shows passed, partial, failed and skipped counts, the plan handoff, Export results and Main window (the card start screen with Start run and Import a plan; there is no Reload here).
- Default position right of center, 380 wide; draggable; the position is saved; Lock position stops dragging; Reset position restores it.
- Fill is pure black at the chosen opacity; nothing is drawn at 0. Text opacity is separate.
- One step at a time: Setup, Do (with copy boxes, one command per box), Expect, Next. Pass, Fail, Skip and Undo stay in fixed places. A note box sits beside them.
- The secure Run button is its own top-level frame, created, changed and shown only out of combat. A state driver hides it for the whole of combat.
- Evidence capture arms when the step appears, before the player acts.

## 4. Commands and diagnostics

The common vocabulary: `settings [page]`, `help [topic]`, `status [topic]`, `get`, `set`, `debug on|off`, `log`, `log clear`. TestThat adds the runner commands (`import`, `start`, `pass`, `partial`, `fail`, `skip`, `undo`, `back`, `next`, `export`, `macro`, `reload`).

UI and commands share validators in `Core/Settings.lua`. Unknown keys, bad values and surplus input are rejected without writes. TestThat's public keys are `card.scale`, `card.background-opacity`, `card.text-opacity` and `card.locked`. The report lists every saved setting, the run status, failures and the recorded lines.

## 5. Reuse boundaries and validation

Adopt the shared terms and contracts locally. Record intentional differences with their reason: TestThat has no Move/Done/Cancel transaction (the card is dragged and locked) and no previews or demo, because it has nothing to preview.

Validation: `make test`, `make check` and strict OpenSpec validation. `test_smoke` loads the whole TOC with the real Ace libraries; `test_options` validates the tree with AceConfig. These do not replace checks on a client: see `docs/test-plan.md`.
