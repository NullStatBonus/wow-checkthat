# Debug logging for testable addons

A CheckThat plan can pass a step on its own when the addon writes one line that proves the step. Without that line, the player has to judge the result and the reviewer has nothing to check. This guide says what a good debug log looks like and how plans use it.

The pattern and formats come from KeepThat, DontDoThat, ClosestVendor and CheckThat. See `docs/contracts.md` for the measured formats. The advice on line wording is guidance, not a rule of the game or of CheckThat.

## The pattern

- **Off by default.** Recording starts only when the player turns it on. Failures that switch a feature off are recorded even when recording is off, so the report always says why something is missing.
- **`/<addon> debug on|off`** turns recording on or off and says so once.
- **`/<addon> log`** opens a report the player can select and copy. `log clear` clears only the log, after a confirmation.
- **Settings labels:** "Record debug information" and "Show debug report".
- **Bounded.** The addon keeps the last few hundred lines (CheckThat keeps 300), each with a time, in saved variables.
- **One area per line.** Lines carry an area such as `recipes`, `items`, `confirm` or `standing`, so a reader can find one feature's lines.
- **Say which scope it is.** ClosestVendor keeps its log per character. The others keep it per account. A plan must name the right saved variable.

## What a line worth asserting on looks like

Each rule below is advice. The examples are real lines read from the addon sources on 2026-11-22. They show the shape; exact wording can change.

1. **One fact per line, with the outcome and the values that matter.** Say what happened and to what.
   - `items: spent %d counted (money dropped %d, price %d)` (DontDoThat)
   - `standing: npc 1234 will trade` (ClosestVendor)
   - A line such as "entered handler" proves nothing.
2. **Log the refusal or skip, not only the success.** Plans need these lines for `absent` checks and negative cases.
   - `confirm: declined <name>` and `reset: <kind> skipped` (DontDoThat)
   - `standing: npc 1234 will not trade (Unfriendly or Hostile)` (ClosestVendor)
3. **Log at the decision point.** Write the line in the code that decides, not in a wrapper or at startup. Startup lines such as `hooked <paths>` repeat at every login and prove only that the addon loaded.
4. **Log the reason for a failure.** Use one clear marker so a check can find it.
   - `FAILED: <error>` (KeepThat, through its failure function)
   - `reset: %s call failed: %s` (DontDoThat)
5. **Log state changes in both directions.** `filter: Recommended turned on` and `... turned off` let a plan check a toggle both ways.
6. **Keep wording stable.** A plan matches the text. If someone rewords a line, every plan that matches it breaks. Reword on purpose and update the plans.
7. **Mark session boundaries.** ClosestVendor writes `---- login ----`. A boundary line helps a reviewer see which lines belong to which run.
8. **Keep secrets out.** Logs are copied into `evidence/`. Do not write real character names, account data or chat text in a line.
9. **Write for the reviewer.** Players never read the log. The reviewer reads it in the `/ct log` report or in the saved variables.

## How a plan uses a line

| Need | Assertion | Note |
| --- | --- | --- |
| Fixed text | `equals` | The whole line must match. |
| Stable part of a line | `contains` | Prefer this for lines with changing values. |
| Changing value | `pattern` | A Lua pattern, for example `^%[ct%] resumed run `. |
| Must not happen | `absent` | Needs a refusal or skip line to prove the code path ran. |
| After this step only | `scope: attempt` | Attempts survive `/reload`. Use `session` only for a line an earlier step wrote. |

A required assertion needs an unconditional line: the code path writes it every time. Use `diagnostic` for extra context that must not fail a step.

## Formats CheckThat reads

- `strings`: a list of `"[area] text"` strings (KeepThat).
- `entries`: a list of `{ t, msg }` (DontDoThat, ClosestVendor, CheckThat).

Add a new addon's saved variable name, path and format to `LOGS` in `tools/ct.py` and to `docs/contracts.md`.

## Publish a fact

A result that is a value, or an event with no log line, can be published as a fact. CheckThat records it as one log line while a run is open, and a plan asserts on it.

```lua
if CheckThat and CheckThat.Report then CheckThat.Report("KeepThat", "freeSlots", 3) end
```

- Keep the guard. The call must not break the addon when CheckThat is missing or old.
- The addon name is the addon's own name. A key names the result in letters, digits, `_`, `.` or `-`, for example `bagFull` or `sell.count`. A value is a string (up to 120 characters), a number or a boolean.
- Report once per result, where the code decides it. Do not report in a loop or an update handler: one addon can record 30 facts a second.
- Prefer your own log line when the event already has one. A fact is for a value or a gap.
- Add the source to the plan: `global: CheckThatDB`, `path: global.facts`, `format: strings`. Then assert `equals: '[KeepThat] freeSlots=3'`, or `contains` for a changing value. See [Write a plan](authoring-plans.md#facts-from-the-addon-under-test).

## Checklist for an addon author

- [ ] Recording is off by default, with `debug on|off` and `log`.
- [ ] The log is bounded and each line has an area and a time.
- [ ] Each behavior a plan will test writes one line at its decision point.
- [ ] Refusals, skips and failures write lines too.
- [ ] Lines hold values that prove the result, and no secrets.
- [ ] Wording is stable, or the plans are updated when it changes.
