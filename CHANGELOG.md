# Changelog

## 0.2.1

Fixed: Steps that list commands, such as /reload, showed copy boxes but no Run button. They now show Run.
Fixed: Main window on the finished-run screen opened the settings window. It now returns to the card start screen.
New: **Addon icon.** TestThat now shows an icon in the AddOns list.

## 0.2.0

Changed: The finished-run screen has a Main window button instead of Reload.
Fixed: The step number in the card header did not change when you moved back. It now shows the step you are viewing.
Fixed: When all checks passed, the list grew into the result buttons. The card now keeps space for it.
New: **Clear checks.** Each step says if TestThat checks it or you confirm it. Checks tick live as TestThat sees your action.
New: Use < and > (or /wtt back and /wtt next) to move between steps. Redo a finished step.
Fixed: After Fail the card stayed on the same step. Fail now moves on.
Fixed: Test plans showed backtick and star marks in the card. The plans now use game colors.
Fixed: Importing a plan after a finished run kept showing "Run complete". The new plan now opens with Start run.
New: **Recent plans.** Pick a plan you used before from a list on the import screen. No paste needed.
New: **Partial result.** Use it when a step mostly works. Add a note to say what did not.
Fixed: The Run button stuck out past the card. It now fits inside.
Fixed: After a reload nothing said the run continued. The card and chat now say so.
Fixed: The saved character name had no realm. It now includes the realm.
New: The window opens when you import a plan, with a Start run button.
Changed: The checklist card shows the step title large, commands beside the step, and a progress bar.
New: **TestThat checklist.** A card shows one test step at a time, what to do, and what to expect.
New: Paste a plan string to import it. Export the results as a string.
New: The addon reads the debug log of the addon under test and records whether the evidence matched.
New: A settings window with Home, Plans, Appearance, Advanced and About pages.
New: Card size, background opacity, text opacity and lock settings.
New: Use `/wtt log` to copy a debug report.
New: Use separate settings for one character, or keep shared settings.
Changed: Settings and commands follow the same layout as KeepThat, DontDoThat and ClosestVendor.
