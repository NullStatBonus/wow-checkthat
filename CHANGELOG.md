# Changelog

## 1.1.0

New: **A gap between two log lines.** A sequence check can name the seconds it allows between two lines. A log that keeps no time for its lines leaves the check unverified.

## 1.0.0


New: **Result sounds.** Each result plays a short sound. A pass that CheckThat records plays two rising notes. A fail that CheckThat records plays two falling notes. An unverified step plays an alert. The last result of a run plays a finish sound. Turn the sounds off in Appearance.
New: **Built-in self-test.** The import window lists "CheckThat self-test (built-in)". Select it to try CheckThat without other tools.
New: **Plans for any addon.** A plan can test any addon and list its commands. The card offers a command only when that addon registered it.
New: **Blocked actions.** CheckThat records the actions that the game blocked during a run. A plan can check that the game blocked nothing. The result is the same with or without BugGrabber.
New: **Cleanup after a step.** After a result, the card shows what to undo before the next step.
New: **Profiles.** A Profiles page lets characters share settings or use their own. Choose, create, copy, reset or delete a profile there. Chat names the profile at login and when you change it.
New: **Plans name the CheckThat they need.** A later CheckThat can make plans that this version cannot read. This version then says that the plan needs a newer CheckThat.
New: **Client census.** Type `/ct census` to record the names this game client gives addons. Wait for the completion message, then type /reload to save it. The census changes no setting and does no game action.
New: **Offline checks match the game client.** A plan can ask for the client version from the addon's TOC file. Older plans keep their results. An offline run reports each name the addon read that the test client did not have.
New: **Lua 5.1 check.** Offline runs and the package check now find code that the game's Lua cannot load or reads differently.
New: **Run start and end for addons.** An addon can ask CheckThat to tell it when a run starts or ends. It can then set up and restore its own test settings.
New: **Checklist of actions.** A step can list its actions. Tick each action on the card when you do it.
New: **Checks when a run starts.** A step can pass when the run starts. The card then goes past it.
New: **Steps for one class or profession.** Such a step does not apply on another character. It does not fail at its time limit.
New: **Checks for the whole run.** A plan check can read every line since the run started, also after a reload. A last "no Lua error" step then sees the errors of this run only.
Changed: **Export names your character.** The results window says that the results include your character and realm name.
Changed: **Deleted runs.** When a new run deletes old runs, chat names each deleted run.
Changed: **A calmer card.** Setup folds to one line. The note opens from "Add note". A small heading names the checks that CheckThat makes. The step title is larger.
Changed: **Pause after each result.** The card shows the result in one large word for 3 seconds. Then it fades to the next step.
Changed: **The start screen lists what a plan reads.** A plan can read the variables of any addon. Your results string can include them. The start screen now names them before you start.
Fixed: **A full addon log with repeated lines.** A check that a line must not appear stayed unverified. It now passes when the line did not appear.
Fixed: **A plan for the other game client.** The start screen asked you to select a category. It now says that the plan is not for this game client.
Fixed: **A plan pattern could freeze the game.** A pattern with stacked wildcards took seconds to check on a line, and the freeze came back after each reload. CheckThat now stops a match that takes too long. The step stays unverified and says why.
Fixed: **A plan with a text pattern that Lua cannot read.** The plan imported, then its check raised an error. Import now refuses it.
Fixed: **A damaged plan string broke the card.** A plan with a wrong field type imported, then raised an error twice a second. Import now refuses it and stores nothing.
Fixed: **Plan tools accepted what the game rejects.** `ct.py` passed an empty value (`null`), empty step text, and a string over the 120000-character import limit. The tool now names each one.
Fixed: **A reload while the card showed a past run.** Your open run did not count as reloaded. A step then asked for a second reload. The reload now marks your open run, and chat names it.
Fixed: **A bar in a category title.** `/ct categories` printed a broken line. Chat now shows the bar.
Fixed: **`/ct start` in lower case.** `/ct start keepthat` printed the usage line. It now starts the run.
Fixed: **Categories window after a profile change.** The window kept the old profile's place until a reload. It now moves at once.
Fixed: **The CT macro stopped following the step.** After a run ended, the macro could keep `/ct status` in every later run. A new run now takes it back. Chat says when the game refuses a macro change.
Removed: **The checkbox for separate settings.** Use the Profiles page instead. Your character profile stays in its list.

## 0.20.1

Changed: **Undo and stale macro presses show in the run.** The report and diff now count presses of an out-of-date CT macro. Undo writes a line to the debug log.
Changed: **Screenshot timing hint.** The collect tool now suggests a screenshot slack when a file lies just outside a step.
Fixed: **A second confirm question showed the old text.** Each confirm question now replaces the one that is open.
Fixed: **Run button in a game that cannot report combat.** CheckThat now treats that game as in combat and leaves the button alone.
Fixed: **A closed card left the Run button on screen.** The button now goes away with the card.
Fixed: **A slash result changed a finished step.** `/ct pass` on a step you went back to now asks for Redo or Undo first.
Fixed: **A full log could pass a check that must fail.** A check that a line is absent now stays unverified when the log is full.
Fixed: **Plans with a bad step id.** Plan import now rejects a step or section id with spaces, capitals or a new line.
Fixed: **Collecting runs.** An interrupted collect no longer blocks a run revision. Moving the card no longer shows a conflict. Diff finds plans in collected files.
Fixed: **A repeated run lost its log evidence.** A step showed "log rolled over" when you played the same plan twice. Checks for a line that must appear can pass. A check that cannot be sure stays unverified.

## 0.20.0

New: **CT macro follows the step.** A new setting, off by default, keeps the CT macro on the commands of the current step. Bind a key to it and play a plan with it and the result keys. The macro never gives a result. It changes only out of combat, and never replaces a macro you changed. Its first line says which step it was made for. A press for another step shows a warning.

## 0.19.0

New: **Version of the tested addon.** Each run now saves the version of the addon you test. Reports can tell which addon version a result belongs to.

## 0.18.0

New: **Entry points for tests.** An addon can register a function with `CheckThat.Entry`. An automatic step can call it and check the result. The call never runs in combat.
New: **Check entry points after login.** A new setting, off by default, calls the entries your plans name after login. It prints one chat line.
Changed: **API version.** `CheckThat.API_VERSION` is now 2. Calls that worked before still work.

## 0.17.0

New: **See the steps of a category.** Each row in the Categories window has a plus button. It lists the steps with their results. A click on a step shows it on the card.
New: **Screenshots outside a step.** The collect tool now counts screenshots that fit no step. It names the nearest step with the option `--verbose`.
New: **Version command.** Type `/ct version` to see the CheckThat version. A test plan can use it to check the version first.
Removed: **Step count in the card header.** The count under the category bar stays.
Fixed: **Reopened steps.** After Undo or a rerun, a step looked untouched in reports. It now carries a marker and shows as awaiting retry.
Fixed: **Row click without a menu.** On some clients a click on a category row did only the first menu item. It now falls back to a button list.

## 0.16.0

New: **Choose categories on the card.** A plan with more than eight categories has a Choose categories button. It opens a list you can page. Home pages its list too.
New: **Remove a category from a run.** A category with no result can leave the run. The Categories window row menu has Remove from run.
New: **Key bindings for results.** Pass, Partial, Fail and Skip can have keys. No key is set until you set one.
Fixed: **Report stacks.** A step that failed and then passed lost the error stack of its failed attempt. Json and junit reports now keep it.
Fixed: **Reopened steps in the report.** After Undo or a rerun, the table showed the old note and evidence. It now says "awaiting retry".
Fixed: **Results from slash commands.** A result from a slash command kept no error stack. It now asks for one.

## 0.15.0

New: **Saved runs say which version wrote them.** A run and each finished attempt now carry a format revision. A run carries the CheckThat version too. Tools use them to read old and new runs.
New: **Newer runs stay safe.** After you go back to an older CheckThat, a run saved by a newer one is kept as it is. A chat line tells you.

## 0.14.0

New: **Failed checks name their log lines.** A check that does not pass saves its rule, how many lines matched and the lines that decided it. Reports and viewers show them.
Changed: **Clearer reasons.** A forbidden line or a fact that does not match now says so. Before, the reason was empty.

## 0.13.1

Fixed: **Large exports.** A run with many failed steps saved more log lines than an export holds. CheckThat now keeps the newest lines and drops the oldest.
Fixed: **One error stack for each attempt.** A step that stayed open when the card refreshed kept a second error stack. It now keeps one.

## 0.13.0

New: **Log lines kept with a failed step.** A failed or unverified step saves the first new lines of the logs it checks. The report shows them.

## 0.12.0

New: **Errors name their addon.** Each recorded Lua error shows the addon from its file path, such as [KeepThat]. A plan can check one addon.
New: **Error stacks.** The first error of a step keeps a short call stack. /ct log shows the newest.
New: **Handler watch.** CheckThat sets its error handler again when another addon takes it during a run.
New: **Card error warning.** An amber line on the card says when CheckThat cannot detect new Lua errors.
Fixed: An addon that took the error handler mid-run hid errors until the next category start. CheckThat now notices within a second.

## 0.11.0

New: **Rerun failed steps.** Type /ct rerun failed. It reopens every failed or unverified step in every category. A row menu item does the same.
Changed: **Reserved category name.** A plan cannot use "failed" as a category id.
Fixed: The rerun question and the reopen message said "1 steps". They now say "1 step".

## 0.10.0

New: **Test categories.** A plan groups its steps. Pick the categories to run when you start. Add one later.
New: **Progress tracker.** The card shows each category in blue, yellow, red or green. A caption says the result in words.
New: **Categories window.** Type /ct tracker to see every category. Click a row to add it, go to its first open step, or run it again.
New: **Unit-test checks.** A step can check a fact's value, how often something happened, and that no Lua error appeared.
New: The commands /ct categories, /ct run, /ct rerun and /ct tracker. A rerun asks first.
Changed: **Automatic steps** can now check that something did not happen. The step waits for its timeout and then records the result.
Changed: The self-test plan has 15 steps in five categories. It checks every kind of check.

## 0.9.1

New: **/ct fact** reports a test fact while a run is open. The self-test now uses it with the Run button.

## 0.9.0

New: **Facts from other addons.** An addon under test can report a fact while you run a plan.
New: A plan step can check a reported fact. An automatic step passes when the fact arrives.

## 0.8.3

Changed: The **debug report and results window** now look like the report window in KeepThat, DontDoThat and ClosestVendor.
Changed: The **import window** now looks like the report window too, with a Recent plans list above the box.
Changed: The results window and the reload reminder no longer name Claude.

## 0.8.2

Fixed: **Past runs** showed an ended run and an unfinished run the same way. An ended run now ends with ", ended".
Fixed: The **Past runs** list ran off the right edge of the window. Each row is now short.

## 0.8.1

Fixed: The download held a Windows script in the CheckThat folder. The script is gone from the download.

## 0.8.0

New: **Past runs.** Home lists your stored runs. Open a run, export it, or delete it.
New: **Runs to keep.** Advanced sets how many runs CheckThat keeps. The oldest runs go first.
New: Opening an ended run only views it. Your current run stays where it was.
Changed: CheckThat saves less data for each step. It also deletes plan copies that no run uses.
Fixed: A "must not appear" check could pass after the game log rolled over. It now stays unverified.
Changed: Open run now asks you to accept first whenever another run is active. Before, it asked only when it replaced an unfinished run.
Fixed: The debug log filled with "run button hidden" lines, about five each second. Checks for a missing line then stayed unverified. The game no longer shows the button again and again, and the log holds one line for each screen.
Fixed: "Must not appear" checks stayed unverified on a full debug log. They now pass or fail from the new lines.
Fixed: The debug log did not show exports, reports or the Open run and Delete run questions. It now does.
Fixed: Large logs made the saved data grow with every step. CheckThat now saves only the logs that a step checks.

## 0.7.1

Changed: **Start screen.** The heading is now the plan title. The step count and "Ready to test" show under it.
Changed: A long plan title shows in full when you hover over it.

## 0.7.0

New: **Run menu.** The card header shows a Run control. It opens Import, End run and Clear plan.
New: Clear plan ends the run and removes the plan. Your results stay for export.
Changed: The Reload button is gone. Use the Run button or type /reload.
Changed: After Clear plan, the ended card shows Import a plan in place of Main window.
Fixed: **Long titles.** A long title ran past the edge of the minimized card. It now stays inside and ends with "...".
Fixed: The minimized card hid its Run menu behind the step counter. The counter now sits next to the buttons.
Fixed: The Start screen was too narrow over a minimized run. Its text ran out of the card.

## 0.6.1

Fixed: **Hidden card.** An automatic step recorded nothing while the card was hidden. It now records the result and the time limit still counts.

## 0.6.0

New: **End run.** Click the card title and choose End run, or type /ct end. CheckThat asks first. The results stay.
New: An ended run shows "Run ended" with Export results. The export and the debug report mark the run ended.

## 0.5.3

Fixed: **Large plan strings.** A small pasted plan string could expand to a huge size and freeze the game while you imported it. Import now stops at the size limit and shows "decoded data too large".

## 0.5.2

Changed: **Short name ct.** The plan format, the tools and the debug log now use the short name ct. The old short name is gone.
Changed: Plan strings now start with !CT1!. Plan files end in .ct. Debug log lines start with [ct].
Changed: The macro that the card creates is now named CT.

## 0.5.1

Fixed: **Run button.** The Run button of the Export results step stayed on screen over the results window. The window now covers it.
Fixed: The Run button stayed on screen after you left its step. It now hides when no step needs it.

## 0.5.0

Changed: **New name: CheckThat.** The addon was called TestThat. The addon site does not allow that name.
Changed: The chat command is now /ct. /checkthat works too. /wtt is gone.

## 0.4.0

New: **Automatic steps.** A plan step can record its own result when the debug log or game state shows your action.
New: An automatic step can also fail or stay open at a time limit. The card shows the seconds left.
New: The card, the debug log and the report show which results TestThat recorded.
Changed: The wait-event step type now shows a wait message on the card.
Fixed: Pressing Pass in combat could change the protected Run button and raise a blocked-action error. The button now waits until combat ends.

## 0.3.3

New: **Debug logging guide.** A new guide tells addon authors what a good debug log looks like.
Changed: The test plan skill now helps an addon that has no debug log. It recommends adding one and marks the steps that need it.

## 0.3.2

Changed: **make install-skill** now installs the plan tools and a private Python with the skill. The skill works without a TestThat checkout.
Changed: The skill now suggests saving plans in the repository you work in.

## 0.3.1

New: **Plan lint.** The plan checker now warns when step text names a slash command that the step does not list.

## 0.3.0

New: **Test plan skill.** Addon authors can ask an agent to draft a test plan for their changes.
New: **make install-skill** copies the skill to your Claude Code skills folder.

## 0.2.2

New: **Safer imports.** A damaged plan string now shows a clear message and keeps your current plan.
Changed: Plan titles, check labels and requirement text must use game colors, not backticks or stars.
Changed: A step with more than four commands has no Run button, so no command runs out of sight.
Fixed: The Run button could still run the old step's commands if you changed steps in combat. It is now hidden during combat.
Fixed: Opening the card for the first time in combat could raise a blocked-action error. The Run button is now built after combat.
Fixed: A step that stayed unverified was lost when you finished the other steps. The run showed as complete. It now stays open.
Fixed: A log that could not be read when a step opened let old log lines count as new. The check now says it has no baseline.
Fixed: A check on a saved value of false never passed. It now does.
Fixed: A step that needs another addon passed when that addon was not loaded. It now waits for the addon.
Fixed: /wtt start hid the card when it was already open. It now shows the card.
Fixed: /wtt undo left the old step on screen. The card now refreshes.
Fixed: A step named snapshots vanished from exported results. It is now kept.
Fixed: Two different plans with the same checksum could replace each other. Each now keeps its own copy.
Fixed: Two testers starting a run in the same second made the same run name. The name now includes a short character tag.
Fixed: A note typed on one step could be saved on another. The note now stays with its step.
Fixed: A reload request on the last step showed no Reload button. The results screen now shows it.
Fixed: Plan titles with a bar character could break chat text. They are now shown safely.
Fixed: The collect tool could write files outside its folder for a strange run name. It now keeps every file inside.

## 0.2.1

New: **Addon icon.** TestThat now shows an icon in the AddOns list.
Fixed: Steps that list commands, such as /reload, showed copy boxes but no Run button. They now show Run.
Fixed: Main window on the finished-run screen opened the settings window. It now returns to the card start screen.

## 0.2.0

New: **TestThat checklist.** A card shows one test step at a time, what to do, and what to expect.
New: Each step says if TestThat checks it or you confirm it. Checks tick live as TestThat sees your action.
New: Use < and > (or /wtt back and /wtt next) to move between steps. Redo a finished step.
New: Pick a plan you used before from a list on the import screen. No paste needed.
New: Use Partial when a step mostly works. Add a note to say what did not.
New: Paste a plan string to import it. Export the results as a string.
New: The window opens when you import a plan, with a Start run button.
New: The addon reads the debug log of the addon under test and records whether the evidence matched.
New: A settings window with Home, Plans, Appearance, Advanced and About pages.
New: Card size, background opacity, text opacity and lock settings.
New: Use /wtt log to copy a debug report.
New: Use separate settings for one character, or keep shared settings.
Changed: The finished-run screen has a Main window button instead of Reload.
Changed: The checklist card shows the step title large, commands beside the step, and a progress bar.
Changed: Settings and commands follow the same layout as KeepThat, DontDoThat and ClosestVendor.
Fixed: The step number in the card header did not change when you moved back. It now shows the step you are viewing.
Fixed: When all checks passed, the list grew into the result buttons. The card now keeps space for it.
Fixed: After Fail the card stayed on the same step. Fail now moves on.
Fixed: Test plans showed backtick and star marks in the card. The plans now use game colors.
Fixed: Importing a plan after a finished run kept showing "Run complete". The new plan now opens with Start run.
Fixed: The Run button stuck out past the card. It now fits inside.
Fixed: After a reload nothing said the run continued. The card and chat now say so.
Fixed: The saved character name had no realm. It now includes the realm.
