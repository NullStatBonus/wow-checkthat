# Changelog

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
