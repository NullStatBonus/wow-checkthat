# In-game test plan

`make test` covers the plan format, evidence checks, run logic, settings and commands against a fake game. This plan keeps only what needs a live client: drawing, protected buttons, reload resume and saved variables.

Setup: copy `TestThat/` into `Interface/AddOns/`, type `/console scriptErrors 1`, then `/reload`. The same plan ships as `plans/selftest.yaml`: import `build/selftest.wtt` with `/wtt import` to run the self-test steps inside TestThat itself. Each check is one action, a `Check:` line with what you should see, and a `Log:` line for the reviewer. Run each section on WoW Forever and on Classic Era.

## 1. Load

1. **No Lua errors.** Log in with the addon enabled.
   Check: no error window appears and the addon is in the AddOns list.
   Log: none; on screen only.

## 2. Settings window

1. **Open the window.** Type `/wtt settings`.
   Check: a window titled TestThat opens at about 600 by 460 with a tree: Home, Plans, Appearance, Advanced, About.
   Log: none; on screen only.
2. **Game Settings entries.** Open Esc, Options, AddOns, TestThat.
   Check: TestThat and its four pages are listed and open.
   Log: none; on screen only.
3. **Scale.** On Appearance, set Scale to 150, then `/wtt set card.scale 100`.
   Check: the card resizes with each change and the slider shows 100 afterwards.
   Log: none; on screen only.
4. **Zero opacity.** Set Background opacity to 0.
   Check: no background or border is drawn. The text stays readable.
   Log: none; on screen only.

## 3. Run

1. **Debug on.** Type `/wtt debug on`.
   Check: chat says "Debug recording is on."
   Log: `[wtt] debug on`.
2. **Import opens the window.** Type `/wtt import`, paste the contents of `build/selftest.wtt`, press Import, then type `/wtt start TestThat`.
   Check: the window opens at once with the plan title and a Start run button. After you select Start run (or type `/wtt start TestThat`) the card shows "Turn debug recording on" with a copy box, a progress bar and Pass, Partial, Fail, Skip and Undo at the bottom.
   Log: `[wtt] run started`.
3. **Recent plans.** Type `/wtt import` again.
   Check: a "Recent plans" button lists the plan you imported. Choosing it opens the window with Start run and no paste.
   Log: `[wtt] reused plan`.
4. **Run button.** Open the second step and click Run. The button sits inside the card beside the first command.
   Check: chat shows a status line, and the card moves on by itself without Pass.
   Log: `[wtt] status requested`, then `[wtt] step self.secure pass auto evidence matched`.
5. **Reload resume.** Open the third step and press Reload.
   Check: after the reload the card is on the same step, a green "Reloaded" line shows under the title, and chat says the run continues. Within a minute the card moves on by itself.
   Log: `[wtt] resumed run`, then `[wtt] step self.reload pass auto evidence matched`.
6. **Card in combat.** Start a fight with a training dummy. Drag, collapse and expand the card.
   Check: the card moves and collapses and no "action blocked" message shows.
   Log: none; on screen only.
7. **Run in combat.** On a step with a Run button, start a fight with a training dummy and move to the next step with the card's > button.
   Check: the Run button is hidden during the fight. After the fight it shows again and runs the commands of the new step.
   Log: none; on screen only.

## 4. Evidence

1. **Auto-check ticks.** On a step with the green TESTTHAT CHECKS THIS STEP banner, do the action.
   Check: the listed check changes from the waiting icon to a green check within a second, and "All checks detected. Press Pass." shows.
   Log: none; on screen only.
2. **Back and forward.** Press < then Redo, then >.
   Check: the earlier step shows what was recorded with a Redo button; Redo brings back the verdict buttons; > returns to the current step.
   Log: none; on screen only.

3. **Unverified without evidence.** Type `/wtt debug off`, repeat the first step of a run and press Pass.
   Check: the card stays on the step and says the evidence is missing. If you finish every other step, the card returns to this step instead of showing the run as complete.
   Log: none; on screen only.
4. **Export.** Finish the run, type `/wtt export`, then `/reload`.
   Check: a box shows a string starting with `!WTT1!`. After the reload `WTF/Account/<account>/SavedVariables/TestThat.lua` holds the run.
   Log: `TestThatDB.global.runs` holds the run with four steps.
5. **Harvest.** Double-click `Copy-WttEvidence.bat` on the PC, then run `tools/wtt.py collect --src evidence-src` and `report` on the Mac.
   Check: `evidence/REPORT.md` lists the run and no unverified evidence.
   Log: none; read the report.
6. **Automatic step shows who records it.** Press < on the card after an automatic step finished.
   Check: the finished step says "recorded by TestThat" next to Recorded: Pass.
   Log: `[wtt] step self.secure pass auto evidence matched`.
7. **Hidden card waits.** Setup: on the Run button step, hide the card with `/wtt` and type `/wtt status`. Then type `/wtt` to show the card.
   Check: the card moves on to the next step within a second of showing.
   Log: `[wtt] status requested`, then `[wtt] step self.secure pass auto evidence matched` after the card is shown.
