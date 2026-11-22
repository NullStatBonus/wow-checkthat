# CurseForge and Wago listing

**Summary:** Walk through the in-game test plans for your addons, tick off each step, and collect evidence for review.

## TestThat

TestThat turns a long manual test plan into a short checklist. A card shows one step at a time: what to do, what to expect and what comes next. It reads the debug log of the addon under test and records whether the evidence matched. It never plays for you. Every action stays your own click or keypress.

### Features

- Import a plan as a pasted string. Export your results as a string.
- Copy commands and a button you click to run a macro. No automated input.
- Evidence from the addon's debug log, kept through `/reload`.
- A settings window for card size, opacity and position. Shared or per-character settings.
- Commands: `/wtt`, `/wtt settings`, `/wtt import`, `/wtt start <addon>`, `/wtt log`.

### Good to know

- Plans are made for KeepThat, DontDoThat and ClosestVendor. Other plans need the plan format in the project repository.
- Results are saved when the game reloads or logs out.
- Works on WoW Forever and Classic Era.
