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
- An addon under test can learn when a run starts or ends, so it can restore its own test settings.
- An addon under test can report a fact with `CheckThat.Report`, and a plan or an automatic step checks it like a log line.
- Group a plan's steps into categories. Pick the categories to run when you start, add one later, jump to one, take one out while it has no result, or run one again. A bar and a Categories window show each category in blue, yellow, red or green, and say the result in words. Open a category in the window to see its steps and jump to one.
- Check fact values (range, tolerance, type, list), how many times an event occurred, and that no Lua error appeared.
- Keep your place through `/reload`.
- Reopen, export or delete an older run from Past runs on the Home page. Choose how many runs to keep in Advanced.
- End a run you will not finish from the Run menu in the card header or with `/ct end`. The results stay for export. The same menu imports another plan or clears the current plan.
- Set card size, opacity and position. Use shared or per-character settings.
- Better with (all optional): BugGrabber and BugSack for error capture, and the addon you test. See the README, "Which tool to use".
- Commands: `/ct`, `/ct settings`, `/ct import`, `/ct start <addon>`, `/ct categories`, `/ct run <category or step id>`, `/ct rerun <category or failed>`, `/ct end`, `/ct export`, `/ct log`, `/ct census`. `/checkthat` works the same as `/ct`.

### Good to know

- Plans are made for KeepThat, DontDoThat and ClosestVendor. Other plans need the plan format in the project repository.
- Results are saved when the game reloads or logs out.
- Each run saves the version of the addon you test, so reports can compare runs across addon versions.
- CheckThat keeps the newest 20 runs by default and deletes the oldest ones first. The run on your card always stays. Change the number in Advanced.
- Works on WoW Classic Era and WoW Forever. Install it like any addon: put the `CheckThat` folder in `Interface/AddOns/`.
- Run is not available in combat. CheckThat shows it again when combat ends.
- CheckThat records Lua errors only while a run is open. It passes every error to the previous handler, names the addon in each line, and sets its handler again if another addon takes it. BugGrabber is optional: with it CheckThat reads its list instead.
- A plan with more than 8 categories shows one bar on the card. Pick its categories with the Choose categories button or on the Home page, 24 at a time.
- Pass, Partial, Fail and Skip have optional key bindings. No key is set by default.
- An optional setting keeps the CT macro on the current step's commands, so a key and the result keys can play a whole plan.
- Blue on the tracker means untested. Yellow means partial or unverified.
- Automatic steps record a result also while the card is hidden. They pause while the game interface is hidden. They read logs and never send input.
