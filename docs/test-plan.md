# In-game test plan

`make test` covers the plan format, evidence checks, run logic, settings and commands against a fake game. This plan keeps only what needs a live client: drawing, protected buttons, reload resume and saved variables.

Setup: copy `CheckThat/` into `Interface/AddOns/`, type `/console scriptErrors 1`, then `/reload`. The same plan ships as `plans/selftest.yaml`: import `build/selftest.ct` with `/ct import` to run the self-test steps inside CheckThat itself. Each check is one action, a `Check:` line with what you should see, and a `Log:` line for the reviewer. Run each section on WoW Forever and on Classic Era.

## 1. Load

1. **No Lua errors.** Log in with the addon enabled.
   Check: no error window appears and the addon is in the AddOns list.
   Log: none; on screen only.

## 2. Settings window

1. **Open the window.** Type `/ct settings`.
   Check: a window titled CheckThat opens at about 600 by 460 with a tree: Home, Plans, Appearance, Advanced, About.
   Log: none; on screen only.
2. **Game Settings entries.** Open Esc, Options, AddOns, CheckThat.
   Check: CheckThat and its four pages are listed and open.
   Log: none; on screen only.
3. **Scale.** On Appearance, set Scale to 150, then `/ct set card.scale 100`.
   Check: the card resizes with each change and the slider shows 100 afterwards.
   Log: none; on screen only.
4. **Zero opacity.** Set Background opacity to 0.
   Check: no background or border is drawn. The text stays readable.
   Log: none; on screen only.

## 3. Run

1. **Debug on.** Type `/ct debug on`.
   Check: chat says "Debug recording is on."
   Log: `[ct] debug on`.
2. **Import opens the window.** Type `/ct import`, paste the contents of `build/selftest.ct`, press Import, then type `/ct start CheckThat`.
   Check: the window opens at once with "Ready to test", the plan title and a Start run button. After you select Start run (or type `/ct start CheckThat`) the card shows "Turn debug recording on" with a copy box, a progress bar and Pass, Partial, Fail, Skip and Undo at the bottom.
   Log: `[ct] run started`.
3. **Recent plans.** Type `/ct import` again.
   Check: a "Recent plans" button lists the plan you imported. Choosing it opens the window with Start run and no paste.
   Log: `[ct] reused plan`.
4. **Run button.** Open the second step and click Run. The button sits inside the card beside the first command.
   Check: chat shows a status line, and the card moves on by itself without Pass.
   Log: `[ct] status requested`, then `[ct] step self.secure pass auto evidence matched`.
5. **Reload resume.** Open the third step and click Run.
   Check: after the reload the card is on the same step, a green "Reloaded" line shows under the title, and chat says the run continues. Within a minute the card moves on by itself.
   Log: `[ct] resumed run`, then `[ct] step self.reload pass auto evidence matched`.
6. **Card in combat.** Start a fight with a training dummy. Drag, collapse and expand the card.
   Check: the card moves and collapses and no "action blocked" message shows.
   Log: none; on screen only.
7. **Run in combat.** On a step with a Run button, start a fight with a training dummy and move to the next step with the card's > button.
   Check: the Run button is hidden during the fight. After the fight it shows again and runs the commands of the new step.
   Log: none; on screen only.
8. **End run.** Start a run and give the first step a result. Click Run in the card header and choose End run, then answer No. Choose End run again and answer Yes.
   Check: after No the run goes on unchanged. After Yes the card shows "Run ended" with Export results and Main window, and has no Undo or Resume. Starting the plan again opens a new run.
   Log: `[ct] run ended`, and `/ct status run` ends with "(run ended)".
9. **Long step title.** Start a run. Open the plan file and give the current step a title of more than 100 characters, or use a plan with one. Click the card's - button to minimize the card, then point at the title.
   Check: the title stays on one line inside the card and ends with "...". A tooltip shows the whole title. The step counter does not touch the Run menu. After you click + the title wraps to at most two lines.
   Log: none; on screen only.
10. **Long plan name.** Import a plan with a title of more than 100 characters, with no run active.
   Check: the text stays inside the card and the Start run button shows at the left edge.
   Log: `[ct] imported plan`.
11. **Import from the Run menu.** Start a run. Click Run in the card header and choose Import.... Press Escape.
   Check: the Run control shows a small arrow and lights up when you point at it. The menu lists Import, End run and Clear plan in that order. The paste box opens, and after Escape the run is unchanged.
   Log: none; on screen only.
12. **Clear plan.** Start a run and give the first step a result. Click Run and choose Clear plan.... Press Escape on the question. Choose Clear plan... again and answer Yes.
   Check: the question names the plan. After Escape the run goes on. After Yes the card shows "Run ended" with Export results and Import a plan, and the recent plans list in the import box no longer holds that plan. Export results still works.
   Log: `[ct] plan cleared`.
13. **Start screen over a minimized run.** Start a run and minimize the card with the - button. Import another plan.
   Check: the card widens to full size. The "Plan ready" text stays inside the card and Start run sits at the left edge. With no plan loaded, Import a plan sits at the left edge instead.
   Log: `[ct] imported plan`.

## 4. Evidence

1. **Auto-check ticks.** On a step with the green CHECKTHAT CHECKS THIS STEP banner, do the action.
   Check: the listed check changes from the waiting icon to a green check within a second, and "All checks detected. Press Pass." shows.
   Log: none; on screen only.
2. **Back and forward.** Press < then Redo, then >.
   Check: the earlier step shows what was recorded with a Redo button; Redo brings back the verdict buttons; > returns to the current step.
   Log: none; on screen only.

3. **Unverified without evidence.** Type `/ct debug off`, repeat the first step of a run and press Pass.
   Check: the card stays on the step and says the evidence is missing. If you finish every other step, the card returns to this step instead of showing the run as complete.
   Log: none; on screen only.
4. **Export.** Finish the run, type `/ct export`, then `/reload`.
   Check: a box shows a string starting with `!CT1!`. After the reload `WTF/Account/<account>/SavedVariables/CheckThat.lua` holds the run.
   Log: `CheckThatDB.global.runs` holds the run with four steps.
5. **Harvest.** Double-click `Copy-CheckThatEvidence.bat` on the PC, then run `tools/ct.py collect --src evidence-src` and `report` on the Mac.
   Check: `evidence/REPORT.md` lists the run and no unverified evidence.
   Log: none; read the report.
6. **Automatic step shows who records it.** Press < on the card after an automatic step finished.
   Check: the finished step says "recorded by CheckThat" next to Recorded: Pass.
   Log: `[ct] step self.secure pass auto evidence matched`.
7. **Hidden card still records.** Setup: on the Run button step, hide the card with `/ct` and type `/ct status`. Then type `/ct` to show the card.
   Check: the card opens on the next step.
   Log: `[ct] status requested`, then `[ct] step self.secure pass auto evidence matched` before the card is shown.
8. **Export window covers the Run button.** On the Export results step, click Run (or type `/ct export`).
   Check: the results window opens over the card and the Run button is hidden behind it. Clicking the window does not press Run.
   Log: none; on screen only.
9. **Run button leaves with its step.** Finish the run on the Export results step, then fight a training dummy until combat ends.
   Check: the results screen shows no Run button, before and after the fight.
   Log: none when the button stayed hidden; `[ct] run button hidden: nothing to run on this screen` if the game showed it and CheckThat hid it again.
