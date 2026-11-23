# CurseForge and Wago listing

**Summary:** Walk through in-game test plans for KeepThat, DontDoThat and ClosestVendor, tick off each step, and collect evidence for review.

## CheckThat

CheckThat turns a long manual test plan into a short checklist. A card shows one step at a time: what to do, what to expect and what comes next. It reads the debug log of the addon under test and records whether the evidence matched. It never plays for you. Every action stays your own click or keypress.

### Features

- Import a plan from a pasted string, or pick a recent plan. Export your results as a string.
- Copy each command from its own box, or click Run to run the step's commands. CheckThat never sends input for you.
- Mark each step Pass, Partial, Fail or Skip. Move back and forth between steps. Redo a step.
- See which steps CheckThat checks itself and which you confirm. Checks turn green as the addon's debug log shows your action.
- Steps marked automatic record their own result when the addon's debug log shows your action, and fail or stay open at a time limit. Your clicks still win.
- Keep your place through `/reload`.
- End a run you will not finish from the card title or with `/ct end`. The results stay for export.
- Set card size, opacity and position. Use shared or per-character settings.
- Commands: `/ct`, `/ct settings`, `/ct import`, `/ct start <addon>`, `/ct end`, `/ct export`, `/ct log`. `/checkthat` works the same as `/ct`.

### Good to know

- Plans are made for KeepThat, DontDoThat and ClosestVendor. Other plans need the plan format in the project repository.
- Results are saved when the game reloads or logs out.
- Works on WoW Classic Era and WoW Forever. Install it like any addon: put the `CheckThat` folder in `Interface/AddOns/`.
- Run is not available in combat. CheckThat shows it again when combat ends.
- Automatic steps record a result also while the card is hidden. They pause while the game interface is hidden. They read logs and never send input.
