# Feature reference

How each CheckThat feature behaves. The README has the short version. Debug log lines are the proof a reviewer reads in `/ct log`.

## Run button

A step that lists commands, and only allowed ones, gets a Run button that runs them in order. The button is hidden during combat and set up again when combat ends.

- A step with more commands than the card has copy boxes (four) gets no button, so no command runs unseen.
- `/script` and `/dump` are not allowed.
- There is no separate Reload button. A step that asks for a reload shows Run beside its `/reload` command. A step without that command, and a plan that asks to share the log after a reload, tell you to type `/reload`.

## Macro that follows the step

With **Keep the CT macro on the current step** on (Advanced, off by default), CheckThat rewrites the `CT` macro each time the card shows a different step. A player drags `CT` to a bar, binds a key to it and plays a plan with a macro key and the result keys.

- The macro starts with a marker line, `/ct macrorun <step id>`, then the step's commands. It never holds `/ct pass` or another result command, so every result is still the player's own key. The marker names the step the macro was written for. `/ct macro` writes the same body. The Run button never runs the marker.
- When the macro key runs, the marker compares its step with the step on the card. A match logs `macro run <step id>` and prints nothing. Another step prints "This macro is for step X. The card shows step Y." and logs `macro stale X card Y`. That happens after combat moved the step, with the setting off, or after you edited the macro and left the marker. The macro cannot stop its other lines, so the commands still run. The marker line only makes the press visible. If you delete the marker, nothing is logged. Evidence needs debug recording on. A plan reads these lines to show that the tester pressed the macro and when it was out of date. Each stale press is also counted as `macroStale` on the step record the card showed, and `ct.py report` and `ct.py diff` show the count.
- A step with no usable commands gets `/ct status` after the marker. A step with commands that no macro can hold (more than four lines, or marker and commands over 255 characters, or not allowed) gets the marker and `/ct status`, and the card says "This step has no macro: its commands do not fit in one."
- CheckThat never changes a macro in combat. After combat the first card refresh writes the macro for the step then shown.
- CheckThat writes only a macro it made. If you edit `CT`, it leaves that macro alone for the rest of the run and makes no second one. A new run, or ticking the setting again, takes the macro back while its first line is still the marker, so a stale macro recovers. Delete the marker line to keep the macro for good. `/ct macro` makes a new one.
- CheckThat makes a macro when you turn the setting on and it has none of its own, and prints its name. The name is `CT`, or `CT2` to `CT9` when you already own `CT`. It prints one chat line if no slot is free.
- A result command in a step (`/ct pass`, `/checkthat fail`) never goes in the macro. The macro holds `/ct status` instead.
- The setting is in the debug report as `macroFollow`.

Debug log: `macroFollow on` and `off`, `macro set <step id>` each time the macro text changes, `macro run <step id>` and `macro stale <macro step id> card <card step id>` when the macro key runs.

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
- A plan can say how many lines a log keeps (`cap` on the log source). A log that holds fewer lines has never dropped one, so where the step opened is certain, also when the last lines are alike. CheckThat's own lists have caps: errors 100, facts 300. The sample and full plans for KeepThat (300), DontDoThat (500), ClosestVendor (300) and CheckThat (300) declare the cap of the addon's debug log, so an absence check or an exact count on those logs can pass while the log holds fewer lines. `tools/ct.py from-md` adds the same caps. Source lines are in `docs/contracts.md`.
- When the last lines it saved appear more than once in the log (a repeated run leaves the same lines), CheckThat takes the last one as where the step opened and marks the position as not exact. A line that must appear can still pass. A "must not appear" check or an exact count stays unverified.
- A log that keeps a known number of lines (`cap`) and is full cannot show that nothing new arrived when it again reads the saved last lines: the new lines may have pushed the old ones out. An absence check stays unverified then.
- Runs saved by an earlier version keep working.
- **Excerpt.** When an attempt records fail or unverified, CheckThat keeps the first 20 new lines (each cut to 200 characters) of every log the step checks, as `excerpt` on the attempt. A log that cannot be read, or whose start is lost, adds none. A pass keeps none. A run keeps at most about 60 000 bytes of them and of the check hit text below: the oldest attempts lose theirs first, so an export stays under its 2 MB limit. The results string stays version 1: the field is added, and older readers ignore it. `tools/ct.py report` prints the lines under the attempt. Debug lines can hold private data, so check an excerpt before you share a results string.

## Version of the addon under test

When a run starts, CheckThat reads the `Version` line of the TOC file of the plan's addon (not its own) and saves it as `targetVersion` on the run. It lets a tool name the addon version a result belongs to: `ct.py diff` shows it in its header and `ct.py trend --by target` names each column by it. The key is missing when the addon is not installed, has no version or the client cannot say. It is never the text "unknown", and a tool reads a missing key as unknown. A run that is reopened or continued keeps the version it started with. `writerVersion` is the version of CheckThat and is a different key (see [Results format](results-format.md)).

## Which lines decided a check

A check that did not pass says what it looked at, so a reviewer or another tool can name the log lines that decided it. CheckThat saves this on the outcome of the attempt (the same read the check judged, so the lines cannot differ from the result). The results string stays version 1 and every key is optional (see [Results format](results-format.md) for the version numbers and the rules for a tool that reads a run): a run saved by an earlier version has none of them, and a tool reads that as unknown, never as zero.

| Key | Meaning |
| --- | --- |
| `kind` | `log`, `log-sequence`, `fact` or `state`. |
| `scope` | `attempt` (the lines after the step opened) or `session` (the whole retained log). Logs and facts only. |
| `source` | The log source the check read. |
| `label` | The label the plan gave the check, if any. |
| `rule` | What the check required, in words, at most 120 characters: `absent: contains "FAILED"`, `count at most 1: pattern "ERR"`, `sequence of 3 lines`, `fact [KT] level eq 3, all`. It holds the plan's literals, which can be a log line. |
| `shape` | The same rule with the plan's literals left out: `absent: contains "…"`, `fact [KT] level eq …`. Safe to show where log text is not. |
| `window` | How many lines the check looked at. |
| `matched` | How many matched: lines, facts that pass the operator, or sequence items found in a row. Missing when the window was lost. |
| `hits` | At most 3 of `{ n, line }`: `n` counts from 1 inside the window, `line` is the text cut to 200 characters. A sequence hit also has `item`, a fact hit also has `value`. |
| `stoppedAt` | A sequence: the first item that was not found. |
| `observed` | A state check: the value it read, cut to 80 characters. |
| `trimmed` | `true` when the hit text was dropped to keep the run small, so a missing `hits` is not "nothing matched". |

- **Which hits.** A forbidden line: the first lines that match. A count over its bound: the first line past the bound, then those after it. A sequence: the last item reached. A fact with `last`: the last fact. With `all`: the first facts that broke the operator, even when later ones passed. With `any`: the last facts that were rejected. With `missing`: the facts that arrived. A line that was never there (unverified, no match) has `matched: 0` and no `hits`.
- **Which outcomes.** Every outcome that is not a pass, also in an attempt that passed (a failing diagnostic never gates it). Passing outcomes keep none of these keys, and the check does not build them.
- **Position and excerpt.** For `scope: attempt` the position `n` is the same position as line `n` of the excerpt of that source, when `n` is 20 or less. Hits carry their own text, so a hit past line 20 is still shown.
- **Size.** Hit text and `observed` count toward the byte budget of a run with the excerpt, for every attempt that kept them (also a passing one). The oldest attempts lose them first, keep `rule`, `shape`, `matched`, `window` and `why`, and set `trimmed` on each check that lost text.
- **Privacy.** Hit lines and values come from debug logs and can hold private data, as the excerpt can. Check a results string before you share it. `ct.py report --format json|junit` gives the `shape` as the rule, and leaves line text, values and the full rule out unless you add `--lines`.
- **Contract.** `schema/run-results.schema.json` describes the run record. `tools/ct.py` rejects a revision whose hits are malformed and names it in `status`.

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
- `/ct version` prints the CheckThat version. With a run open it also reports the fact `[CheckThat] version=<major*10000 + minor*100 + patch>`, so 0.17.0 is `version=1700`. A plan starts with a step that runs it and checks `op: ge` against its own version, because a game that loads an older copy of the addon gives results that mean nothing. With no run open it only prints.
- `/ct fact` reports the fact `[CheckThat] selftest=1` through the same call. The self-test step "Report a fact" runs it with the Run button, so a plan can test the API with one click. With no run open it says so and records nothing.
- `CheckThat.Entry(addon, name, fn)` registers a function a plan step can call (see [Entry points](#entry-points)). It returns true when it stores the entry.
- `CheckThat.API_VERSION` is 2. Later versions only add to the API. A call that works now keeps working.
- CheckThat keeps the lines in `CheckThatDB.global.facts`. A plan reads them as a log: `global: CheckThatDB`, `path: global.facts`, `format: strings`. See [Write a plan](authoring-plans.md#facts-from-the-addon-under-test).
- A step counts only the facts reported after it opened. A fact is data and CheckThat never runs it.

Debug log: `facts recorded <addon> <key>` and `facts dropped ...` with the reason. The report adds `Facts: <count>, last: <line>`.

### Entry points

An addon can expose a function for a test to call:

```lua
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if CheckThat and CheckThat.Entry then CheckThat.Entry("KeepThat", "add", function(a, b) return a + b end) end
end)
```

- Register when the player logs in, not at file scope: an addon that CheckThat lists as optional loads before CheckThat, so `CheckThat.Entry` does not exist yet at file scope. Use `PLAYER_LOGIN`. CheckThat refuses a bad name (up to 32 letters, digits, `_` or `-` for the addon and up to 42 for the entry) or a value that is not a function. A registration while a run is open is fine: a run survives `/reload`.
- An auto step names the entry in `call: {addon: KeepThat, entry: add, args: [2, 3]}`. Arguments are text, numbers or booleans. CheckThat calls it when the step opens, outside combat, and never calls anything the addon did not register.
- The outcome is the fact `[KeepThat] entry.add=5`. Several returns join with commas. Other outcomes: `(none)`, `threw: <text>`, `not registered`, `refused: in combat`. The step checks it as any fact line.
- A step that stays open across a reload does not call again.
- **Check entry points after login** (settings page, off by default) calls the entries that your imported plans name, about 3 seconds after login and never in combat. It records no fact and opens no run. It prints one chat line, such as `Self-check: 2 of 3 entry checks matched. First miss: <step>: <line>`. A step matches when it has a required `equals` or `contains` log check and all of them hold. It runs code that other addons registered, so leave it off unless you test them. The setting is in the debug report as `loginCheck`.

Debug log: `self-check: <matched> of <total> entry checks matched`, `self-check skipped: in combat`, `loginCheck on` and `off`, `entries registered <addon>.<name>`, `entries called <addon>.<name>: <result>` and `entries refused ...`.

## Categories and the tracker

Key bindings: Pass, Partial, Fail and Skip are in Key Bindings under AddOns, CheckThat. They record the same result as the card buttons, with the note typed on the card, and no key is set by default. A key does nothing, and says so in chat, when the card is hidden or shows no step with buttons. Keys never send a protected action. With debug on, a key writes `[ct] key <result>` before it records, or `[ct] key <result> ignored: card not visible` when it does nothing.

A plan groups its steps into categories. A plan that declares none uses each section as a category, so every plan has them.

- **Choose.** The Home page and the card start screen list the plan's categories with a checkbox each, all checked. Clear the ones you do not want. A plan with one category shows no list. The card start screen lists up to 8 categories. A plan with more shows "N of M categories picked" and a Choose categories button. The button opens a window with the same checkboxes, 14 rows a page, that scrolls with the mouse wheel or the < and > page buttons. Home lists 24 at a time with Previous page and Next page. Both lists change the same choice.
- **Not picked.** A step in a category you did not pick is deselected. It is not offered, it does not count as open and it cannot fail the run. The report lists it apart from skipped steps.
- **Categories window.** The Categories control on the card, or `/ct tracker`, opens a second window. It has one row for each category with a colored square, the title, the state in words, and how many steps passed, failed and are still open. It has no overall count of its own: each row has its own, and the card's caption has the total. It lists up to 14 rows. A longer list scrolls with the mouse wheel or the < and > page buttons, and a line says which rows show. A row has an arrow and a hint: click it for actions. Where the game has no context menu, a click shows a small list with one button per action; Esc closes the list and leaves the window open. A plus button at the left of a row lists the steps of that category in plan order, with each result in words and a mark, also for a category that is not picked or a step that is not for this client. The minus button closes the list. The window keeps its top edge and grows downward. Rows start closed and stay as you left them while the run is on the card. A click on a step row shows that step on the card; it changes no result and picks no category. Steps that are not in the run show but do nothing when clicked. The paging counts step rows like category rows. Esc closes the window. Move it by dragging. It remembers its place and comes back after a reload if it was open. It uses the card's background and text opacity, and draws nothing at zero.
- **Add or go.** Click a row in the window. Add to run adds a category you did not pick and keeps your place. Go to first open step moves you to it. `/ct run <category>` does both. `/ct run <step id>` shows one step.
- **Remove from run.** Remove from run (a row menu item) takes a picked category out of the run. It shows only for a category with no result. It refuses when a step of the category has a finished attempt, so no result is lost, and when it is the last picked category; a line says why. The shown step stays unless it was in the removed category, then the card moves to the next open step. Add to run brings it back. Log: `select <id>` and `deselect <id>`.
- **Rerun.** Rerun category (a row menu item, and `/ct rerun <category>`) asks first, then reopens the steps that have a result. Earlier attempts stay in the export. Undo no longer reaches those steps. A step that Undo or a rerun reopened carries `reopened` in its saved record until it gets a new result or leaves the run. The report shows it as "awaiting retry", also when Undo removed the step's only attempt.
- **Rerun failed.** `/ct rerun failed`, and the row menu item Rerun failed and unverified steps in all categories, asks first and then reopens every picked step whose result is fail or unverified, in every category. Passed steps stay. `failed` is reserved: a plan cannot use it as a category id, or as a section id when it declares no categories. The question and the message use the singular for one step.
- **Tracker.** With two to eight categories the card shows one bar segment each in plan order, and a caption such as "1 failed · 3 of 8 passed" (or "2 partial", "1 unverified", "untested", "in progress", "passed", "all skipped" in front). With more than eight it shows one bar for the whole run. Use the Categories window to see each category. Point at a segment to read its category in words. The segments only show a tooltip. They never take a click. A segment shows what happened to its steps: green for passed, yellow for partial or unverified and red for failed, side by side, so one failure among six passes is mostly green with a red end. What is left shows the track: dim blue while steps are untested, grey otherwise, and dark grey for a category you did not pick.
- **Colors.** Red: a step failed. Yellow: a step is partial or unverified. Green: every step has a result and one passed. Blue: some steps are still untested, whether or not others have results (the words say "untested" or "in progress"). Grey: every step skipped. A category you did not pick is shown dim. The same words and counts show on the Home page and in `/ct categories`.
- **Text opacity.** The tracker follows the card's text opacity. At zero it draws nothing.

Debug log: `trigger <category|step> <name>: step <id>`, `undo <step id>: reopened`, `verdict refused <step id>: step has a result`, `select <category>`, `rerun <category or failed>: <n> steps reopened`, `tracker open`, `tracker expand <category>`, `tracker collapse <category>`, `show step <id>`. The report adds `Categories: overall <state>` and one line for each category.

## Unit-test checks

A step can check more than a log line. Every check is data. Nothing in a plan runs.

- **Fact values.** `kind: fact` reads the facts an addon reports with `CheckThat.Report`. A value is a boolean for `true` and `false`, a number when it reads as one, else text. Operators: `eq`, `ne`, `gt`, `ge`, `lt`, `le`, `between` (two numbers, ends included), `approx` (with `tolerance`), `in` (a list), `matches` (a pattern), `contains`, `type` (number, boolean or string), `exists` and `missing`. If no matching fact arrived, the check is unverified. Facts that break the operator fail. `which` is `last` (default), `any` or `all`.
- **Counts.** `count: { exactly: 2 }`, `min` or `max` on a `log` or `fact` check. Too many fails. Too few is unverified, as the line can still arrive. A count that allows none follows the rules of an absence check. A check that is judged at the verdict (an upper-bound count, an absence, a missing fact) shows as failed on the card as soon as it can no longer pass, such as a third report when the step needs exactly two. A count of exactly n, an absence and a check that a fact is missing need a log whose last twelve lines are mostly different, so the start of the step can be found. A plan that checks them should report something that changes on each call. The self-test adds a `seq` fact for this. An automatic step cannot use `exactly` or `max`, as more can arrive later.
- **Quiet sources.** A log source with `quiet: true` treats no new lines as a result, so an absence check or a count of zero can pass.
- **State operators.** `state` checks accept the same new operators.
- **Lua errors.** While a run is open CheckThat records each Lua error as one line in `CheckThatDB.global.errors` (the time, a counter, the addon in brackets, then the message cut to 200 characters; 100 kept, 30 a second). The addon is the name in `Interface\AddOns\<Name>\` in the message, or `?` when there is no path. A library an addon carries has that addon's path; a library loaded as its own addon has its own name. A plan checks one addon with `contains: "[KeepThat]"` or `pattern`. The time and counter make every line different, so a check that no error appeared can find where the step began. It chains to the handler that was set before, so other addons still see the error. BugGrabber makes `seterrorhandler` do nothing once it has the slot. Then CheckThat reads BugGrabber's list and records one line for each rise of an error counter, so a repeated error counts too. When nothing records errors (no handler of ours and no BugGrabber), judging a result adds a line that says so, and a no-error check fails. A plan reads the list as a quiet `strings` source: an absence check is "no Lua error", a `contains` check is "this error happened". The first error of each step also keeps its call stack in `CheckThatDB.global.errorStacks` (one line, same time and counter as its error line, cut to 600 characters, 20 kept, never the locals). With BugGrabber holding the slot, the stack is the one BugGrabber stored. `/ct log` shows the newest as `Last error stack:`. When another addon takes the error handler after CheckThat, CheckThat sets its own again (at most once a second, from the card refresh and before a result is judged). A step that reads the error list shows the amber line "CheckThat cannot detect new Lua errors." on the card while nothing records errors, and lays the card out again when it comes or goes. Limits: an error that another handler swallowed before CheckThat took the slot back is not recorded, and while CheckThat cannot see errors the line it adds is tagged `[CheckThat]`, so a check for one other addon's name can still pass (the amber line says so).
- **Self-test commands.** `/ct selftest facts` reports a level, a ratio and two hits. `/ct selftest error` passes a test message to the error handler. The game may show its error window.

Debug log: `errors recorded an error`, `errors dropped errors: over 30 a second` and `errors another addon took the error handler: set ours again` (the first five times a run). The report adds `Errors: <count> recorded, handler: current|replaced|blocked|off`.

## Long titles

A title that does not fit stays inside the card and ends with "...". The minimized card shows it on one line and shows the whole title when you point at it. The expanded card allows two lines. A single word that is wider than the card is cut too.
