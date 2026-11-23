# wow-checkthat

In-game test runner (**CheckThat**, `/ct`) plus tooling that turns the manual test plans of KeepThat, DontDoThat and ClosestVendor into a deterministic format, walks the tester through them, and gathers evidence for review.

No input is ever automated. Every game action stays a player click or keypress; the runner only shows text to copy, a button the player clicks, and reads logs and state.

## Flow

1. Author or convert a plan: `plans/<addon>.yaml` (schema: `schema/test-plan.schema.json`).
   Draft from an existing doc: `.venv/bin/python tools/wtt.py from-md ../wow-keepthat/docs/test-plan.md --addon KeepThat -o plans/keepthat.yaml`
2. Compile to an import string: `make build` writes `build/*.wtt` (`!WTT1!...`).
3. In game: `/ct import`, paste, then `/ct start KeepThat`. The card shows the step, what to do (with copy boxes), what to expect, and what comes next. Pass / Partial / Fail / Skip / Undo. A claimed pass without log evidence is recorded as *unverified*.
4. `/ct export` gives a `!WTT1!` results string. `/reload` saves the run to `CheckThat.lua` saved variables.
5. Harvest: `.venv/bin/python tools/wtt.py collect` (default source `../shared-addon-resources/saved`, or `--src <WTF dir>` / `WTT_WTF`), then `.venv/bin/python tools/wtt.py report` writes `evidence/REPORT.md`. Paste a results string with `.venv/bin/python tools/wtt.py import-results "<string>"` (a file path works too).

**Run button.** A step that lists commands, and only allowed ones, gets a Run button that runs them in order. It is hidden during combat and set up again when combat ends. A step with more commands than the card has copy boxes (four) gets no button, so no command runs unseen. `/script` and `/dump` are not allowed.

**Auto steps.** A plan step can set `auto: true`. It must verify by assertions only (no `player`), have at least one required check, and have no required absence check. While the card is shown, CheckThat re-reads the checks twice a second and records the pass itself when every required check is met. A step can also set `timeout` (5 to 300 seconds, counted from when the step opens, also across `/reload`). When the time runs out, a contradicted check records fail and missing evidence records unverified. A check that is wrong for a moment and then right passes. CheckThat only reads the logs and state the card already shows. It never sends input or runs a command. Pass, Fail, Skip and Undo still work and win if you press them first. A step recorded this way says "recorded by CheckThat" on the card. The debug log reads `step <id> <verdict> auto evidence <result>`. The report adds `auto=<count>` to the counts and marks the step. A hidden card, a hidden game interface, or a Start screen for another plan stops it from recording until the run shows again. After an automatic unverified result the step waits for you and does not retry by itself. The `wait-event` action kind is valid only on an auto step. The card shows "Wait. CheckThat records the result when the checks below are met." unless the step has its own text.

The plans in `plans/` are short samples (4 to 7 steps each) that `make build` compiles. The full conversions of the sibling test plans are kept in `plans/full/` and are validated by the tests but not built; compile one with `tools/wtt.py compile plans/full/<name>.yaml -o build/<name>-full.wtt`.

Screenshots: set `screenshot: true` on a step; the card asks for Print Screen (the addon never captures). `collect` copies screenshots taken inside an attempt's time window (`--shots <folder>`, default `Screenshots` beside `--src`).

**Classic Era per-character data.** The sibling script `Copy-WowSavedVariables.ps1` (in the parent folder next to the addon folders, not in this repository) copies only account-level saved variables for Era, so ClosestVendor's per-character log (`ClosestVendorCharDB`) is missing from the shared copy. Run `collect --src "<WoW>/_classic_era_/WTF"` against the real folder instead (or drop `-SharedOnly` for Era in the script).

**First live run.** Build (`make build`), copy `CheckThat/` to `Interface/AddOns/` (the parent folder's `Deploy-WowAddons.ps1` does it), `/ct import` with the contents of `build/selftest.wtt`, `/ct start CheckThat`. It exercises the card, copy boxes, the Run button, log evidence and reload resume with no sibling addon. Then `/ct export`, `/reload`, and harvest. Next: `build/dontdothat.wtt`.

**Harvest on Windows.** Double-click `Copy-WttEvidence.bat` (it runs `tools/Copy-WttEvidence.ps1`; `/reload` or log out first so the game writes the files). It copies CheckThat and the three addons' saved variables (including Era per-character files) and Screenshots into `evidence-src/`; then on the Mac run `.venv/bin/python tools/wtt.py collect --src evidence-src` and `report` (they need LuaJIT, which the Windows PC does not have).

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

`make install-skill` installs the `wtt-test-plan` Claude Code skill to `~/.claude/skills/` (`SKILL_DIR=<dir>` changes the target). The install includes a copy of the plan tools and a private Python with PyYAML and jsonschema, so the skill works in any addon repository with no checkout. It needs Python 3 with `venv` and network access once. Run it again after the tools change; the skill reports the tools version it uses.

Deploy: `Deploy-WowAddons.ps1` in the parent folder picks up `CheckThat/` like the other addons.

Requirements live in `openspec/`.
