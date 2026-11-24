# CheckThat

CheckThat (`/ct`) is an in-game test runner for World of Warcraft Classic Era and Forever. It walks a tester through a plan of test steps for an addon, reads the addon's debug log to check what happened, and exports the results for review.

CheckThat never plays for you. Every game action stays a real click or keypress. The runner shows text to copy, a button you click, and reads logs and state.

This repository holds the addon (`CheckThat/`), the plans for KeepThat, DontDoThat and ClosestVendor (`plans/`), and the tools and coding-agent skills that write plans and read finished runs back.

## Quick start

1. Copy the `CheckThat` folder into `Interface/AddOns/`.
2. Run `make build` (it needs the Python setup under Develop). It writes plan strings to `build/*.ct`.
3. In game, type `/ct import` and paste a plan string, for example `build/selftest.ct`. Then type `/ct start CheckThat`.
4. For each step, read what to do and what to expect, then press Pass, Partial, Fail or Skip. A pass the logs do not support is recorded as *unverified*.
5. Type `/ct export` for a results string, then `/reload` so the game saves the run.

To turn the saved run into a report, see [Collect evidence](docs/harvesting.md).

## Features

- **Card.** One step at a time: what to do (with copy boxes), what to expect and what comes next. Back, next, undo and a note for each result.
- **Run button.** Runs the step's allowed commands in order. It is hidden during combat. [Details](docs/features.md#run-button)
- **Log evidence.** CheckThat reads the addon's debug log and marks each check met or not. [Details](docs/features.md#saved-log-positions)
- **Automatic steps.** A step marked `auto` records its own result when the checks are met. Your click still wins. [Details](docs/features.md#automatic-steps)
- **Facts from other addons.** An addon can publish a named fact with `CheckThat.Report`, and a plan checks it like a log line. [Details](docs/features.md#facts-from-other-addons)
- **Run menu.** Import a plan, end the run or clear the plan from the card header. [Details](docs/features.md#run-menu)
- **Past runs.** Home lists stored runs. Open, export or delete one. [Details](docs/features.md#past-runs)
- **Reload safe.** The run and its place survive `/reload`.
- **Screenshots.** A step can ask for Print Screen. CheckThat never captures. [Details](docs/harvesting.md#screenshots)

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
| `/ct import` | Paste a plan string, in the same window style as the debug report. |
| `/ct start <addon>` | Start a run for an imported plan. |
| `/ct end` | End the current run after confirmation. The card has an End run item in its Run menu too. |
| `/ct pass`, `/ct partial [note]`, `/ct fail [note]`, `/ct skip [note]` | Record the result of the current step. Partial means it mostly works. |
| `/ct undo` | Undo the last result. |
| `/ct back`, `/ct next` | Move to the previous or next step. The card has < and > buttons too. |
| `/ct export` | Show the results string. |
| `/ct macro` | Create a macro for the current step. |
| `/ct fact` | Report a test fact during a run. The self-test uses it. |
| `/ct reload` | Reload the interface so saved variables are written. |

## Settings

Open them with `/ct settings`, or Esc, Options, AddOns, CheckThat.

| Page | What it holds |
| --- | --- |
| Home | Current run (open the checklist, export results), Start a run (import a plan, pick a plan, Start run) and Past runs. |
| Plans | Remove a plan. |
| Appearance | Size and opacity, position, Lock position and Reset position. |
| Advanced | Profile (separate settings for this character), **Runs to keep** and Debug (record debug information, show the debug report). |
| About | The command list and help. |

**Runs to keep** is 5 to 100, default 20, for all profiles. The oldest runs go first. The current run of any character always stays. CheckThat deletes the extra runs when you start a run. The debug report prints every setting and `Stored: <n> runs (limit <n>), <n> plan copies`.

## Good to know

- Results are saved when the game reloads or logs out.
- Run is not available in combat. It comes back when combat ends.
- A step with more commands than the card has copy boxes (four) gets no Run button, so no command runs unseen. `/script` and `/dump` are not allowed.
- A long plan or step title ends with "..." and shows in full when you point at it.
- A step that checks a log with no saved position stays unverified. It never counts the whole log as new.

## Plans, evidence and skills

- [Write a plan](docs/authoring-plans.md): the plan format, compile, and the sample and full plans.
- [Collect evidence](docs/harvesting.md): `collect`, `report`, per-character data on Classic Era, and Windows.
- [Plan skills](docs/skills.md): `ct-test-plan` and `ct-verify` for Claude Code, Codex and other agents, and the Claude Code plugin.
- [Debug logging](docs/debug-logging.md): what a good addon debug log looks like.
- [Feature reference](docs/features.md): how each feature behaves, including the debug log lines.
- [Manual test plan](docs/test-plan.md).

## Develop

```
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
make test      # build, luajit tests, python tests
make check     # packaging and version checks
```

Requirements live in `openspec/`. The release steps are in [docs/publishing.md](docs/publishing.md).
