# Feature reference

How each CheckThat feature behaves. The README has the short version. Debug log lines are the proof a reviewer reads in `/ct log`.

## Run button

A step that lists commands, and only allowed ones, gets a Run button that runs them in order. The button is hidden during combat and set up again when combat ends.

- A step with more commands than the card has copy boxes (four) gets no button, so no command runs unseen.
- `/script` and `/dump` are not allowed.
- There is no separate Reload button. A step that asks for a reload shows Run beside its `/reload` command. A step without that command, and a plan that asks to share the log after a reload, tell you to type `/reload`.

## Run menu

While a run is active, the card header shows a Run control with a small arrow, next to the "CheckThat" title. It highlights when you point at it. Click it for three items:

- **Import...** opens the same box as the Import a plan button, with your recent plans. It leaves the run alone until you import or pick a plan.
- **End run...** see [End run](#end-run).
- **Clear plan...** see [Clear plan](#clear-plan).

A client without a menu API has no Clear plan, and a click on Run asks to end the run directly.

## Clear plan

Choose Clear plan... in the Run menu. CheckThat names the plan and asks first. If you agree:

- The run ends as with End run.
- The plan leaves your loaded plans and your recent list.
- The recorded results stay. The card shows "Run ended" with Export results, and the results string still works. The stored copy of the plan stays for the ended run.
- The ended card offers Import a plan in place of Main window.

The start screen shows the plan title as its heading, with the step count and "Ready to test. Select Start run." under it. With no plan the heading reads "No plan yet". The start screen is always full width, also when a run is minimized, and its first button sits at the left edge.

Debug log: `plan cleared <addon>`.

## End run

Choose End run in the Run menu, or type `/ct end`. CheckThat asks first, also when no step has a result yet.

- An ended run keeps every result, note and attempt. Steps without a result stay as they were.
- The card shows "Run ended" with Export results and Main window, and takes no verdict, Undo or Resume.
- The export string, `/ct status run` and the debug report mark the run ended. The saved run holds an `endedAt` time. A run saved before this feature has none and reads as not ended.
- Start the plan again for a new run.

Debug log: `run ended <run id>`.

## Past runs

Home lists every stored run under Past runs, newest first. A row is short so the list stays inside the window: the date and time, the plan title (cut after 24 characters), the character name without its realm, and the pass, fail and open counts as three numbers. A run that has ended shows ", ended" after the counts. The list stays hidden while no run is stored.

Pick a run, then choose:

- **Open run.**
  - An ended run shows its results on the card, read-only. Your current run stays as it was. Start a run, or open the current run, to return to it.
  - An unfinished run of your own becomes the current run. If another run of yours is active, CheckThat asks you to accept first. That run leaves the card and stays in the list until newer runs push it out.
  - Opening the current run asks nothing.
  - The attempt that the opened run left open starts again, so lines that came from other runs do not count.
  - A run that has not ended and belongs to another character cannot be opened, only exported or deleted.
- **Export run.** Shows the results string.
- **Delete run.** Names the run in full and asks first.

Debug log: `run open asked <id>`, `run opened <id>`, `run delete asked <id>`, `run deleted <id>`, `run pruned <id>` and `run exported <id>`. A cancelled question leaves no `run opened` line.

## Runs to keep

Advanced sets how many runs CheckThat keeps (5 to 100, default 20), for all profiles.

- The oldest runs go first. The current run of any character always stays.
- CheckThat deletes the extra runs when you start a run, not while you move the slider.
- A plan copy that no run, loaded plan or recent plan uses is deleted when you import or clear a plan, delete a run, or a run is pruned.

The debug report prints `Stored: <n> runs (limit <n>), <n> plan copies`, and the log reads `report requested: Stored: ...`.

## Saved log positions

When a step opens, CheckThat saves where each log that the step checks stands: its length and its last 12 lines. It saves no other log.

- A step that checks a log without a saved position stays unverified. It never counts the whole log as new.
- A full log drops its oldest line with every new line. This is normal and CheckThat still finds where the step opened.
- Only when the last lines it saved are all the same line (a flood) can it not show that a line is absent. A "must not appear" check then stays unverified unless the line is there (then it fails).
- Runs saved by an earlier version keep working.

## Automatic steps

A plan step can set `auto: true`. It must verify by assertions only (no `player`), have at least one required check, and have no required absence check.

- While the card is shown, CheckThat re-reads the checks twice a second and records the pass itself when every required check is met.
- A step can also set `timeout` (5 to 300 seconds, counted from when the step opens, also across `/reload`). When the time runs out, a contradicted check records fail and missing evidence records unverified. A check that is wrong for a moment and then right passes.
- CheckThat only reads the logs and state the card already shows. It never sends input or runs a command.
- Pass, Fail, Skip and Undo still work and win if you press them first.
- The card says "recorded by CheckThat" on a step recorded this way.
- A hidden game interface, or a Start screen for another plan, stops recording until the run shows again. A hidden card does not stop it.
- After an automatic unverified result the step waits for you and does not retry by itself.
- The `wait-event` action kind is valid only on an auto step. The card shows "Wait. CheckThat records the result when the checks below are met." unless the step has its own text.

Debug log: `step <id> <verdict> auto evidence <result>`. The report adds `auto=<count>` to the counts and marks the step.

## Facts from other addons

An addon under test can tell CheckThat what it did. CheckThat records the fact as one log line, and a plan checks it like any other log line.

```lua
if CheckThat and CheckThat.Report then CheckThat.Report("KeepThat", "bagFull", true) end
```

- `CheckThat.Report(addon, key, value)` records `[addon] key=value` and returns true. It records nothing and returns false when no run is open or an argument is not valid. It never raises an error.
- `addon` is 1 to 32 letters, digits, `_` or `-`. `key` is 1 to 48 of the same plus `.`. `value` is a string of up to 120 characters with no control characters, a finite number or a boolean. Tables and functions are refused.
- One addon can record 30 facts a second. Facts over that are dropped. The list keeps the newest 300 lines.
- `CheckThat.API_VERSION` is 1. Later versions only add to the API. A call that works now keeps working.
- CheckThat keeps the lines in `CheckThatDB.global.facts`. A plan reads them as a log: `global: CheckThatDB`, `path: global.facts`, `format: strings`. See [Write a plan](authoring-plans.md#facts-from-the-addon-under-test).
- A step counts only the facts reported after it opened. A fact is data and CheckThat never runs it.

Debug log: `facts recorded <addon> <key>` and `facts dropped ...` with the reason. The report adds `Facts: <count>, last: <line>`.

## Long titles

A title that does not fit stays inside the card and ends with "...". The minimized card shows it on one line and shows the whole title when you point at it. The expanded card allows two lines. A single word that is wider than the card is cut too.
