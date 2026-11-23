# wow-checkthat

In-game test runner (**CheckThat**, `/ct`) plus tooling that turns the manual test plans of KeepThat, DontDoThat and ClosestVendor into a deterministic format, walks the tester through them, and gathers evidence for review.

No input is ever automated. Every game action stays a player click or keypress; the runner only shows text to copy, a button the player clicks, and reads logs and state.

## Flow

1. Author or convert a plan: `plans/<addon>.yaml` (schema: `schema/test-plan.schema.json`).
   Draft from an existing doc: `.venv/bin/python tools/ct.py from-md ../wow-keepthat/docs/test-plan.md --addon KeepThat -o plans/keepthat.yaml`
2. Compile to an import string: `make build` writes `build/*.ct` (`!CT1!...`).
3. In game: `/ct import`, paste, then `/ct start KeepThat`. The card shows the step, what to do (with copy boxes), what to expect, and what comes next. Pass / Partial / Fail / Skip / Undo. A claimed pass without log evidence is recorded as *unverified*.
4. `/ct export` gives a `!CT1!` results string. `/reload` saves the run to `CheckThat.lua` saved variables.
5. Harvest: `.venv/bin/python tools/ct.py collect` (default source `../shared-addon-resources/saved`; `--wow <game dir>` / `CT_WOW` collects `_classic_era_` and `_forever_` with their `WTF` and `Screenshots` folders; `--src <WTF dir>` / `CT_WTF` names one folder and wins), then `.venv/bin/python tools/ct.py report` writes `evidence/REPORT.md`. The report starts each run with a table of every step: verdict, evidence (`met`, `bad`, `missing` or `none`), attempt count and note. Detail lines follow for steps that did not pass. Paste a results string with `.venv/bin/python tools/ct.py import-results "<string>"` (a file path works too).

**Local paths.** `tools/ct.py` reads `KEY=VALUE` lines from `$CT_ENV`, `.ct.env` in the working folder (git-ignored) and `~/.checkthat.env`, in that order. A variable already set wins, and a flag wins over both. `CT_WOW` is the game folder (see Harvest); `CT_WTF` and `CT_SHOTS` name one folder each.

**Run button.** A step that lists commands, and only allowed ones, gets a Run button that runs them in order. It is hidden during combat and set up again when combat ends. A step with more commands than the card has copy boxes (four) gets no button, so no command runs unseen. `/script` and `/dump` are not allowed. There is no separate Reload button. A step that asks for a reload shows Run beside its `/reload` command. A step without that command, and a plan that asks to share the log after a reload, tell you to type `/reload`.

**Run menu.** While a run is active, the card header shows a Run control with a small arrow, next to the "CheckThat" title. It highlights when you point at it. Click it for three items: Import..., End run... and Clear plan.... Import... opens the same box as the Import a plan button, with your recent plans. It leaves the run alone until you import or pick a plan.

**Clear plan.** Choose Clear plan... in the Run menu. CheckThat names the plan and asks first. If you agree, the run ends as with End run, and the plan leaves your loaded plans and your recent list. The recorded results stay: the card shows "Run ended" with Export results, and the results string still works. The ended card offers Import a plan in place of Main window. The start screen shows the plan title as its heading, with the step count and "Ready to test. Select Start run." under it. A long title shows in full on hover. With no plan the heading reads "No plan yet". The start screen is always full width, also when a run is minimized, and its first button sits at the left edge. The debug log reads `plan cleared <addon>`. The stored copy of the plan stays for the ended run. A client without a menu API has no Clear plan. A click on Run asks to end the run directly.

**Past runs.** Home lists every stored run under Past runs, newest first, with date, plan, character and counts. A run that has ended shows ", ended" after the counts. It stays hidden while no run is stored. Pick a run, then choose Open run, Export run or Delete run. Each row starts with the date and time. Open run on an ended run shows its results on the card, read-only. Your current run stays as it was. Start a run, or open the current run, to return to it. Open run on an unfinished run of your own makes it the current run. CheckThat asks you to accept first whenever another run of yours is active. If you open an unfinished run, the current run leaves the card and stays in the list until newer runs push it out. If you open an ended run, the current run stays. Opening the current run asks nothing. The attempt that the opened run left open starts again, so lines that came from other runs do not count. A run that has not ended and belongs to another character cannot be opened, only exported or deleted. Delete run names the run and asks first. The debug log reads `run open asked <id>`, `run opened <id>`, `run delete asked <id>`, `run deleted <id>`, `run pruned <id>` and `run exported <id>`. A cancelled question leaves no `run opened` line.

**Runs to keep.** Advanced sets how many runs CheckThat keeps (5 to 100, default 20), for all profiles. The oldest runs go first. The current run of any character always stays. CheckThat deletes the extra runs when you start a run, not while you move the slider. A plan copy that no run, loaded plan or recent plan uses is deleted when you import or clear a plan, delete a run, or a run is pruned. The debug report prints `Stored: <n> runs (limit <n>), <n> plan copies`, and the log reads `report requested: Stored: ...`.

**Saved log positions.** When a step opens, CheckThat saves where each log that the step checks stands: its length and its last 12 lines. It saves no other log. A step that checks a log without a saved position stays unverified, and never counts the whole log as new. A full log drops its oldest line with every new line, so this is normal and CheckThat still finds where the step opened. Only when the last lines it saved are all the same line (a flood) can it not show that a line is absent, so a "must not appear" check stays unverified unless the line is there (then it fails). Runs saved by an earlier version keep working.

**End run.** Choose End run in the Run menu, or type `/ct end`. CheckThat asks first, also when no step has a result yet. An ended run keeps every result, note and attempt. Steps without a result stay as they were. The card then shows "Run ended" with Export results and Main window, and takes no verdict, Undo or Resume. The export string, `/ct status run` and the debug report mark the run ended. The debug log reads `run ended <run id>`. The saved run holds an `endedAt` time. A run saved before this feature has none and reads as not ended. Start the plan again for a new run. On a client without a menu API, a click on Run asks to end the run directly.

**Long titles.** A title that does not fit stays inside the card and ends with "...". The minimized card shows it on one line and shows the whole title when you point at it. The expanded card allows two lines. A single word that is wider than the card is cut too.

**Auto steps.** A plan step can set `auto: true`. It must verify by assertions only (no `player`), have at least one required check, and have no required absence check. While the card is shown, CheckThat re-reads the checks twice a second and records the pass itself when every required check is met. A step can also set `timeout` (5 to 300 seconds, counted from when the step opens, also across `/reload`). When the time runs out, a contradicted check records fail and missing evidence records unverified. A check that is wrong for a moment and then right passes. CheckThat only reads the logs and state the card already shows. It never sends input or runs a command. Pass, Fail, Skip and Undo still work and win if you press them first. A step recorded this way says "recorded by CheckThat" on the card. The debug log reads `step <id> <verdict> auto evidence <result>`. The report adds `auto=<count>` to the counts and marks the step. A hidden game interface or a Start screen for another plan stops it from recording until the run shows again. A hidden card does not stop it. After an automatic unverified result the step waits for you and does not retry by itself. The `wait-event` action kind is valid only on an auto step. The card shows "Wait. CheckThat records the result when the checks below are met." unless the step has its own text.

The plans in `plans/` are short samples (4 to 7 steps each) that `make build` compiles. The full conversions of the sibling test plans are kept in `plans/full/` and are validated by the tests but not built; compile one with `tools/ct.py compile plans/full/<name>.yaml -o build/<name>-full.ct`.

Screenshots: set `screenshot: true` on a step; the card asks for Print Screen (the addon never captures). `collect` copies screenshots taken inside an attempt's time window (`--shots <folder>`, default `Screenshots` beside `--src`).

**Classic Era per-character data.** The sibling script `Copy-WowSavedVariables.ps1` (in the parent folder next to the addon folders, not in this repository) copies only account-level saved variables for Era, so ClosestVendor's per-character log (`ClosestVendorCharDB`) is missing from the shared copy. Run `collect --src "<WoW>/_classic_era_/WTF"` against the real folder instead (or drop `-SharedOnly` for Era in the script).

**First live run.** Build (`make build`), copy `CheckThat/` to `Interface/AddOns/` (the parent folder's `Deploy-WowAddons.ps1` does it), `/ct import` with the contents of `build/selftest.ct`, `/ct start CheckThat`. It exercises the card, copy boxes, the Run button, log evidence and reload resume with no sibling addon. Then `/ct export`, `/reload`, and harvest. Next: `build/dontdothat.ct`.

**Harvest on Windows.** Double-click `tools/Copy-CheckThatEvidence.bat` (it runs `Copy-CheckThatEvidence.ps1` beside it; `/reload` or log out first so the game writes the files). It copies CheckThat and the three addons' saved variables (including Era per-character files) and Screenshots into `evidence-src/`; then on the Mac run `.venv/bin/python tools/ct.py collect --src evidence-src` and `report` (they need LuaJIT, which the Windows PC does not have).

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
| `/ct log`, `/ct log clear` | Copy the debug report. Clear it after confirmation. |
| `/ct import` | Paste a plan string. |
| `/ct start <addon>` | Start a run for an imported plan. |
| `/ct end` | End the current run after confirmation. The card has an End run item in its Run menu too. |
| `/ct pass`, `/ct partial [note]`, `/ct fail [note]`, `/ct skip [note]` | Record the result of the current step. Partial means it mostly works. |
| `/ct undo` | Undo the last result. |
| `/ct back`, `/ct next` | Move to the previous or next step. The card has < and > buttons too. |
| `/ct export` | Show the results string. |
| `/ct macro` | Create a macro for the current step. |
| `/ct reload` | Reload the interface so saved variables are written. |

## Develop

```
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
make test      # build, luajit tests, python tests
```

### Plan-writing skill

What a good addon debug log looks like: [docs/debug-logging.md](docs/debug-logging.md).

`make install-skill` installs the `ct-test-plan` Claude Code skill to `~/.claude/skills/` (`SKILL_DIR=<dir>` changes the target). The install includes a copy of the plan tools and a private Python with PyYAML and jsonschema, so the skill works in any addon repository with no checkout. It needs Python 3 with `venv` and network access once. Run it again after the tools change; the skill reports the tools version it uses.

Deploy: `Deploy-WowAddons.ps1` in the parent folder picks up `CheckThat/` like the other addons.

Requirements live in `openspec/`.
