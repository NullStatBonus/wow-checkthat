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
- A plan can say how many lines a log keeps (`cap` on the log source). A log that holds fewer lines has never dropped one, so where the step opened is certain, also when the last lines are alike. CheckThat's own lists have caps: errors 100, facts 300.
- Runs saved by an earlier version keep working.

## Automatic steps

A plan step can set `auto: true`. It must verify by assertions only (no `player`) and have at least one required check. A check that something did not happen (an absence, a missing fact, a count of exactly or at most n) needs a `timeout`.

- While the card is shown, CheckThat re-reads the checks twice a second and records the pass itself when every required check is met.
- A step can also set `timeout` (5 to 300 seconds, counted from when the step opens, also across `/reload`). When the time runs out, a contradicted check records fail and missing evidence records unverified. A check that is wrong for a moment and then right passes.
- A check that something did not happen cannot be shown the moment it holds, as more could arrive. The step waits for its timeout and records pass if the check still holds. It records fail at once when the check can no longer hold, such as a third report when it needs exactly two. The card shows the seconds left.
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
- `/ct fact` reports the fact `[CheckThat] selftest=1` through the same call. The self-test step "Report a fact" runs it with the Run button, so a plan can test the API with one click. With no run open it says so and records nothing.
- `CheckThat.API_VERSION` is 1. Later versions only add to the API. A call that works now keeps working.
- CheckThat keeps the lines in `CheckThatDB.global.facts`. A plan reads them as a log: `global: CheckThatDB`, `path: global.facts`, `format: strings`. See [Write a plan](authoring-plans.md#facts-from-the-addon-under-test).
- A step counts only the facts reported after it opened. A fact is data and CheckThat never runs it.

Debug log: `facts recorded <addon> <key>` and `facts dropped ...` with the reason. The report adds `Facts: <count>, last: <line>`.

## Categories and the tracker

A plan groups its steps into categories. A plan that declares none uses each section as a category, so every plan has them.

- **Choose.** The Home page and the card start screen list the plan's categories with a checkbox each, all checked. Clear the ones you do not want. A plan with one category shows no list. The card start screen lists up to 8 categories. Home lists up to 24.
- **Not picked.** A step in a category you did not pick is deselected. It is not offered, it does not count as open and it cannot fail the run. The report lists it apart from skipped steps.
- **Categories window.** The Categories control on the card, or `/ct tracker`, opens a second window. It has one row for each category with a colored square, the title, the state in words, and how many steps passed, failed and are still open. It has no overall count of its own: each row has its own, and the card's caption has the total. It lists up to 14 rows. A longer list scrolls with the mouse wheel or the < and > page buttons, and a line says which rows show. A row has an arrow and a hint: click it for actions. Esc closes the window. Move it by dragging. It remembers its place and comes back after a reload if it was open. It uses the card's background and text opacity, and draws nothing at zero.
- **Add or go.** Click a row in the window. Add to run adds a category you did not pick and keeps your place. Go to first open step moves you to it. `/ct run <category>` does both. `/ct run <step id>` shows one step.
- **Rerun.** Rerun category (a row menu item, and `/ct rerun <category>`) asks first, then reopens the steps that have a result. Earlier attempts stay in the export. Undo no longer reaches those steps.
- **Tracker.** With two to eight categories the card shows one bar segment each in plan order, and a caption such as "1 failed · 3 of 8 passed" (or "2 partial", "1 unverified", "untested", "in progress", "passed", "all skipped" in front). With more than eight it shows one bar for the whole run. Use the Categories window to see each category. Point at a segment to read its category in words. The segments only show a tooltip. They never take a click. A segment shows what happened to its steps: green for passed, yellow for partial or unverified and red for failed, side by side, so one failure among six passes is mostly green with a red end. What is left shows the track: dim blue while steps are untested, grey otherwise, and dark grey for a category you did not pick.
- **Colors.** Red: a step failed. Yellow: a step is partial or unverified. Green: every step has a result and one passed. Blue: some steps are still untested, whether or not others have results (the words say "untested" or "in progress"). Grey: every step skipped. A category you did not pick is shown dim. The same words and counts show on the Home page and in `/ct categories`.
- **Text opacity.** The tracker follows the card's text opacity. At zero it draws nothing.

Debug log: `trigger <category|step> <name>: step <id>`, `select <category>`, `rerun <category>: <n> steps reopened`. The report adds `Categories: overall <state>` and one line for each category.

## Unit-test checks

A step can check more than a log line. Every check is data. Nothing in a plan runs.

- **Fact values.** `kind: fact` reads the facts an addon reports with `CheckThat.Report`. A value is a boolean for `true` and `false`, a number when it reads as one, else text. Operators: `eq`, `ne`, `gt`, `ge`, `lt`, `le`, `between` (two numbers, ends included), `approx` (with `tolerance`), `in` (a list), `matches` (a pattern), `contains`, `type` (number, boolean or string), `exists` and `missing`. If no matching fact arrived, the check is unverified. Facts that break the operator fail. `which` is `last` (default), `any` or `all`.
- **Counts.** `count: { exactly: 2 }`, `min` or `max` on a `log` or `fact` check. Too many fails. Too few is unverified, as the line can still arrive. A count that allows none follows the rules of an absence check. A check that is judged at the verdict (an upper-bound count, an absence, a missing fact) shows as failed on the card as soon as it can no longer pass, such as a third report when the step needs exactly two. A count of exactly n, an absence and a check that a fact is missing need a log whose last twelve lines are mostly different, so the start of the step can be found. A plan that checks them should report something that changes on each call. The self-test adds a `seq` fact for this. An automatic step cannot use `exactly` or `max`, as more can arrive later.
- **Quiet sources.** A log source with `quiet: true` treats no new lines as a result, so an absence check or a count of zero can pass.
- **State operators.** `state` checks accept the same new operators.
- **Lua errors.** While a run is open CheckThat records each Lua error as one line in `CheckThatDB.global.errors` (the time, a counter, then the message cut to 200 characters; 100 kept, 30 a second). The time and counter make every line different, so a check that no error appeared can find where the step began. It chains to the handler that was set before, so other addons still see the error. BugGrabber makes `seterrorhandler` do nothing once it has the slot. Then CheckThat reads BugGrabber's list and records one line for each rise of an error counter, so a repeated error counts too. When nothing records errors (no handler of ours and no BugGrabber), judging a result adds a line that says so, and a no-error check fails. A plan reads the list as a quiet `strings` source: an absence check is "no Lua error", a `contains` check is "this error happened".
- **Self-test commands.** `/ct selftest facts` reports a level, a ratio and two hits. `/ct selftest error` passes a test message to the error handler. The game may show its error window.

Debug log: `errors recorded an error` and `errors dropped errors: over 30 a second`. The report adds `Errors: <count> recorded, handler: current|replaced|blocked|off`.

## Long titles

A title that does not fit stays inside the card and ends with "...". The minimized card shows it on one line and shows the whole title when you point at it. The expanded card allows two lines. A single word that is wider than the card is cut too.
