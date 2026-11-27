# CheckThat

CheckThat (`/ct`) is an in-game test runner for World of Warcraft Classic Era and Forever. It walks a tester through a plan of test steps for an addon, reads the addon's debug log to check what happened, and exports the results for review.

CheckThat never plays for you. Every game action stays a real click or keypress. The runner shows text to copy, a button you click, and reads logs and state.

This repository holds the addon (`CheckThat/`), the DontDoThat plan (`plans/`; KeepThat keeps its own), and the tools and coding-agent skills that write plans and read finished runs back.

## Quick start

1. Copy the `CheckThat` folder into `Interface/AddOns/`.
2. Run `make build` (it needs the Python setup under Develop). It writes plan strings to `build/*.ct`.
3. In game, type `/ct import` and choose **CheckThat self-test (built-in)**, or paste a plan string such as `build/selftest.ct`. Then select Start run.
4. For each step, read what to do and what to expect, then press Pass, Partial, Fail or Skip. A pass the logs do not support is recorded as *unverified*.
5. Type `/ct export` for a results string, then `/reload` so the game saves the run.

To turn the saved run into a report, see [Collect evidence](docs/harvesting.md).

## Features

- **Card.** One step at a time: what to do (a checklist when a step lists several actions, with copy boxes), what to expect and what CheckThat checks. Setup folds away, and a note opens when you need one. Back, next and undo. [Details](docs/features.md#step-card)
- **Run button.** Runs the step's allowed commands in order. It is hidden during combat. [Details](docs/features.md#run-button)
- **Log evidence.** CheckThat reads the addon's debug log and marks each check met or not. A failed or unverified step keeps the first new log lines for the report. [Details](docs/features.md#saved-log-positions)
- **Automatic steps.** A step marked `auto` records its own result when the checks are met, and the card pauses 3 seconds on it. A step marked `async` is checked when the run starts. Your click still wins. [Details](docs/features.md#automatic-steps)
- **Steps for one character.** A step can need a class or a profession. On another character it does not apply. [Details](docs/features.md#steps-for-one-character)
- **Run start and end.** An addon can register `CheckThat.OnRun` to set up and restore its own test state when a run starts or stops. [Details](docs/features.md#run-start-and-end)
- **Entry points.** An addon can register a function with `CheckThat.Entry`, and an auto step calls it and checks the result. [Details](docs/features.md#entry-points)
- **Facts from other addons.** An addon can publish a named fact with `CheckThat.Report`, and a plan checks it like a log line. [Details](docs/features.md#facts-from-other-addons)
- **Run menu.** Import a plan, end the run or clear the plan from the card header. [Details](docs/features.md#run-menu)
- **Past runs.** Home lists stored runs. Open, export or delete one. [Details](docs/features.md#past-runs)
- **Categories.** A plan groups its steps into categories. Pick them when you start a run, add one later, jump to one, or run one again. [Details](docs/features.md#categories-and-the-tracker)
- **Progress tracker.** One bar segment for each category in blue, yellow, red or green (grey when skipped), and a caption that says the result in words. The Categories window (`/ct tracker`) lists every category, also with a dozen or more. A row can also take a category out of the run while it has no result. The plus button on a row lists its steps with their results. A click on a step shows it on the card. [Details](docs/features.md#categories-and-the-tracker)
- **Unit-test checks.** A step can check a fact's value (range, tolerance, type, list, pattern), count how many times something happened, and check that no Lua error appeared. [Details](docs/features.md#unit-test-checks)
- **Reload safe.** The run and its place survive `/reload`.
- **Screenshots.** A step can ask for Print Screen. CheckThat never captures. `ct.py collect` counts screenshots that fit no step. [Details](docs/harvesting.md#screenshots)

## Commands

`/checkthat` is the long form of `/ct` and takes the same arguments.

| Command | What it does |
| --- | --- |
| `/ct` | Open or close the checklist card. |
| `/ct settings [page]` | Open settings: home, plans, appearance, advanced, about. |
| `/ct help [topic]` | Help for appearance, diagnostics and runs. |
| `/ct status [topic]` | Show the run status, the settings, or both. Topics: `run`, `settings`. |
| `/ct get <key>`, `/ct set <key> <value>` | Read or change a card setting (`card.scale`, `card.background-opacity`, `card.text-opacity`, `card.locked`). |
| `/ct debug on`, `/ct debug off` | Record or stop the debug log. |
| `/ct log`, `/ct log clear` | Copy the debug report in a window like the one KeepThat, DontDoThat and ClosestVendor use. Clear it after confirmation. |
| `/ct import` | Paste a plan string, or choose the built-in self-test or a recent plan, in the same window style as the debug report. |
| `/ct start <addon>` | Start a run for an imported plan. The addon name works in any letter case. |
| `/ct end` | End the current run after confirmation. The card has an End run item in its Run menu too. |
| `/ct pass`, `/ct partial [note]`, `/ct fail [note]`, `/ct skip [note]` | Record the result of the current step. Partial means it mostly works. |
| `/ct undo` | Undo the last result. |
| `/ct back`, `/ct next` | Move to the previous or next step. The card has < and > buttons too. |
| `/ct export` | Show the results string. |
| `/ct macro` | Create a macro for the current step. With **Keep the CT macro on the current step** on, the macro follows each step. |
| `/ct categories` | List each category of the run with its state (failed, partial or unverified, passed, untested, in progress, all skipped, not picked) and its passed, failed and open counts. |
| `/ct tracker` | Open or close the Categories window: one row for each category with its color, state in words and passed, failed and open counts. Click a row to add it, go to its first open step or rerun it. The plus button on a row lists its steps. |
| `/ct run <category or step id>` | Show the first open step of a category, adding the category to the run if it was not picked. Or show one step. |
| `/ct rerun <category or failed>` | Reopen the steps of a category, or every failed or unverified step with `failed`. Earlier attempts stay in the export. |
| `/ct version` | Show the CheckThat version. During a run it also reports the version as the test fact `version` (0.17.0 is 1700), so a plan can check for a version or newer. |
| `/ct reload` | Reload the interface so saved variables are written. |

Developer commands. The self-test and the tools use them. They work, but they are not stable: a later version may change or move them.

| Command | What it does |
| --- | --- |
| `/ct macrorun <step id>` | The first line of the CT macro (see `/ct macro`). It compares the id with the step on the card and logs `macro run` or `macro stale`. It records no result. |
| `/ct selftest facts`, `/ct selftest error` | Report typed test facts, or raise a test error, so the self-test can check them. |
| `/ct fact` | Report a test fact during a run. The self-test uses it. |
| `/ct census` | Record the names this game client provides (globals, API tables, widget methods) in the saved variables, for `ct.py census`. It refuses in combat and waits while you fight. |

## Settings

Open them with `/ct settings`, or Esc, Options, AddOns, CheckThat.

| Page | What it holds |
| --- | --- |
| Home | Current run (the categories with their state, open the checklist, export results), Start a run (import a plan, pick a plan, pick the categories, Start run) and Past runs. |
| Plans | Remove a plan. |
| Appearance | Size and opacity, position, Lock position and Reset position. |
| Advanced | Profile (separate settings for this character), **Runs to keep**, **Keep the CT macro on the current step** (off by default; see [Macro that follows the step](docs/features.md#macro-that-follows-the-step)), **Check entry points after login** (off by default; see [Entry points](docs/features.md#entry-points)) and Debug (record debug information, show the debug report). |
| About | The command list and help. |

**Runs to keep** is 5 to 100, default 20, for all profiles. The oldest runs go first. The current run of any character always stays. CheckThat deletes the extra runs when you start a run, exported or not, and says so in chat: "Deleted the oldest run (<plan>) to keep 20." The debug report prints every setting and `Stored: <n> runs (limit <n>), <n> plan copies`.

## Good to know

- Results are saved when the game reloads or logs out.
- A plan with more than 8 categories shows one overall bar on the card. Its start screen has a Choose categories button that opens a paged list, and Home pages its list 24 at a time. Use `/ct tracker` to see each category.
- Pass, Partial, Fail and Skip have key bindings under Key Bindings, AddOns, CheckThat. No key is set by default. A key works only while the card shows a step.
- Blue on the tracker means untested, also while some steps of the category have results. Yellow means partial or unverified. Red means fail, green means pass, and grey means all skipped. [Details](docs/features.md#categories-and-the-tracker)
- CheckThat records Lua errors only while a run is open. With BugGrabber loaded, CheckThat reads BugGrabber's error counts instead of setting its own handler. When an addon takes the handler later, CheckThat sets its own again within a second while the card is shown, or when a result is judged. Each error line names the addon from its file path (`[KeepThat]`), and the first error of a step keeps a short call stack for `/ct log`. BugGrabber and BugSack are optional: CheckThat works without them and reads BugGrabber's list when it holds the handler. Blocked and forbidden actions are their own list, recorded by CheckThat itself, so a "no Lua error" step gives the same result with or without BugGrabber.
- Run is not available in combat. It comes back when combat ends.
- A plan can read the saved variables and globals of any addon, and a results string can include what they hold. The start screen lists the variables a plan reads. The debug report shows them as `Plan reads`. Check a results string before you share it. It also includes your character and realm name, and the export window says so. [Details](docs/features.md#which-lines-decided-a-check)
- With **Keep the CT macro on the current step** on, bind a key to the macro CheckThat names (`CT` unless you own one) and play a plan with it and the result keys. The macro holds a marker line (`/ct macrorun <step id>`) and commands, never a result. A press for another step prints a warning and logs `macro stale`. It changes out of combat only. If you edit the macro, it stays as you left it for the rest of that run. A new run, or ticking the setting again, takes it back while its first line is still the marker. Delete the marker line to keep the macro for good. A step whose commands do not fit in a macro (over four lines or 255 characters) gets `/ct status`. The debug report shows `macroFollow`.
- A step with more commands than the card has copy boxes (four) gets no Run button, so no command runs unseen. `/script` and `/dump` are not allowed.
- A plan can be for any addon. Its own slash commands get Run buttons only when that addon registered them in the game, or declared them with `CheckThat.Commands`; the start screen lists them and the debug report shows `Plan commands`. [Details](docs/authoring-plans.md#commands-of-the-addon-under-test)
- A long plan or step title ends with "..." and shows in full when you point at it.
- Each run saves the version of the addon you test (the plan's addon), when the game can tell it. `ct.py diff` and `ct.py trend --by target` show it. A run from an older CheckThat has none.
- A step that checks a log with no saved position stays unverified. It never counts the whole log as new.
- Import refuses a plan whose text pattern Lua cannot read (an open `(` or `[`, a lone `%`). A log line that takes too long to match leaves its check unverified, and a very long log may show "still checking the log" for a refresh or two. [Details](docs/features.md#unit-test-checks)

## Plans, evidence and skills

- [Write a plan](docs/authoring-plans.md): the plan format, compile, and the sample and full plans.
- [Results format](docs/results-format.md): the saved run record, its version numbers and the rules for a tool that reads it.
- [Set up the tools](docs/setup.md): Python on Windows, macOS and Linux, and where `collect` finds the game.
- [Collect evidence](docs/harvesting.md): `collect`, `status`, `show`, `browse` (a terminal viewer), `report` (Markdown, JSON or JUnit), per-character data on Classic Era, and Windows. `collect` needs no LuaJIT, takes `--plan` to collect any addon's saved variables and `--shot-slack` for screenshot timing. `diff` compares two finished runs and `trend` lines up many. `coverage` lists the commands, settings and spec requirements no plan step or unit test touches (`--harness` reads settings from the addon's registered options). `doctor` says where `collect` looks and why it found nothing.
- [Plan skills](docs/skills.md): `ct-test-plan` and `ct-verify` for Claude Code, Codex and other agents, and the Claude Code plugin.
- [Debug logging](docs/debug-logging.md): what a good addon debug log looks like.
- [Which tool to use](docs/tools-guide.md): what CheckThat does not do, and the optional addons that make it better.
- [Feature reference](docs/features.md): how each feature behaves, including the debug log lines.
- [Manual test plan](docs/test-plan.md).

## Develop

```
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt   # Windows: docs/setup.md
make test      # build, luajit tests, python tests
make check     # packaging and version checks
make mutate    # on demand: change CheckThat/ one small way at a time and list the changes the Lua tests miss (LIMIT=300, FILES='CheckThat/Core/*.lua')
luajit tests/replay_plan.lua build/<plan>.ct   # play a compiled plan in the fake client
.venv/bin/python tools/ct.py replay plans/<plan>.yaml --sv <fixture dir>   # judge log checks against saved variables, no game
.venv/bin/python tools/ct.py offline plans/<plan>.yaml   # run the plan's offline block (mocks, entry calls, fake events), no game; --client era|forever|both
.venv/bin/python tools/ct.py replay-flow plans/<plan>.yaml   # play a plan for each client; works for any addon's plan and from the installed skill
.venv/bin/python tools/ct.py lines plans/<plan>.yaml --addon-src <addon folder>   # check each asserted log line and fact key appears in the addon's source
.venv/bin/python tools/ct.py report --addon-src <addon folder> --plan plans/<plan>.yaml   # warn about a run of another build (version from the TOC) or an older plan
```

Requirements live in `openspec/`. The release steps are in [docs/publishing.md](docs/publishing.md).
