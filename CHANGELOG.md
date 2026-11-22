# Changelog

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
