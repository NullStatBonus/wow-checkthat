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
   Check: the window opens at once with the plan title as its heading, "N steps. Ready to test. Select Start run." under it, and a Start run button. After you select Start run (or type `/ct start CheckThat`) the card shows "Turn debug recording on" (the card records its result by itself once you type the command) with a copy box, a progress bar and Pass, Partial, Fail, Skip and Undo at the bottom.
   Log: `[ct] run started`.
3. **Recent plans.** Type `/ct import` again.
   Check: the import window looks like the report window (title bar, scroll box, same frame). A "Recent plans" list above the box holds the plan you imported. Choosing it opens the window with Start run and no paste.
   Log: `[ct] reused plan`.
4. **Run button.** Open the second step and click Run. The button sits inside the card beside the first command.
   Check: chat shows a status line, and the card moves on by itself without Pass.
   Log: `[ct] status requested`, then `[ct] step self.secure pass auto evidence matched`.
5. **Reload resume.** Open the third step and click Run.
   Check: after the reload the card is on the same step, the hint under Do says "Reloaded", and chat says the run continues. Within a minute the card moves on by itself.
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
   Check: the title stays on one line inside the card and ends with "...". A tooltip shows the whole title. The header has no step counter. The count under the category bar is the only one. After you click + the title wraps to at most two lines.
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
   Check: the card widens to full size. The plan title and the text under it stay inside the card and Start run sits at the left edge. With no plan loaded, Import a plan sits at the left edge instead.
   Log: `[ct] imported plan`.
14. **Reopen a past run.** End one run and start another. Open Esc, Options, AddOns, CheckThat, Home. Under Past runs, pick the ended run and press Open run. Accept the question.
   Check: the ended run's row ends with "ended" and the current run's row does not. A question comes first and says your current run stays. After you accept, the card shows that run as "Run ended" with its results. Open the current run again: the card returns to it with no question.
   Log: `[ct] run open asked`, then `[ct] run opened`.
15. **Delete a past run.** Under Past runs, pick a run and press Delete run. Press Accept.
   Check: the question names the run and comes first. After Accept the run leaves the list. With no run left, Past runs disappears.
   Log: `[ct] run delete asked`, then `[ct] run deleted`.
16. **Runs to keep.** Keep at least six runs. On Advanced, drag Runs to keep down to 5 and back up to 15. Then start a run.
   Check: the list keeps every run while you drag. Lower the slider to 5 and start a run: the list keeps five runs and the oldest are gone. The run on the card stays.
   Log: `[ct] run pruned`.
17. **Macro follows the step.** On Advanced, turn on Keep the CT macro on the current step. Drag the CT macro from the macro window to a bar and bind a key to it. Bind keys to Pass and Skip under Key Bindings, AddOns, CheckThat. Start a run with a plan that has commands. Play three steps with only those keys.
   Check: each press of the macro key runs the commands of the step on the card, and the Pass key moves the card on. The macro never records a result by itself.
   Log: `[ct] macroFollow on`, then `[ct] macro set <step id>` for each step with a new macro text, and `[ct] macro run <step id>` for each key press on the step the macro was written for.

18. **A result needs Redo.** Pass a step, press the back arrow to show it, then type `/ct fail`.
   Check: chat says the step has a result and to use Redo this step or Undo first. The step still shows Pass.
   Log: `[ct] verdict refused <step id>: step has a result`, and no `[ct] step <id> fail` line for it.
19. **Tick the actions of a step.** Import `build/checkthat-0.21.ct`, start it and play to "Tick each action". Click the first box, then the text of the second action, then the second box again.
   Check: each click ticks or clears its box. The Setup line was open when the step first showed. Pass works with a box empty.
   Log: `[ct] step ct2100.checklist action 1 ticked`, then `action 2 ticked` and `action 2 cleared`.
20. **The card pauses on an automatic result.** On "The card pauses on an automatic result", click Run.
   Check: the card keeps the step on screen with a green "Recorded: Pass (recorded by CheckThat)" line, fades for about 3 seconds, then shows the next step at full brightness.
   Log: `[ct] card holds ct2100.pause for 3 s`.
21. **A result key during the pause.** Bind a key to Pass. Press the back arrow, press Redo on "The card pauses on an automatic result", click Run, and press the key while the card fades.
   Check: chat says "CheckThat recorded that step by itself. The card now shows the next step." The next step has no result.
   Log: `[ct] result pass ignored: the card was showing an automatic result`.
22. **The step title stands out.** Look at any step title on each client.
   Check: the title is larger than the other text and has a dark outline. Take a screenshot for the listing page.
   Log: none; on screen only.

## 4. Evidence

1. **Auto-check ticks.** On a step with the green "CheckThat checks" heading, do the action.
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
   Log: `CheckThatDB.global.runs` holds the run with its steps, each with a category.
5. **Harvest.** On the computer with the game, run `tools/ct.py collect` and then `report` (see docs/setup.md).
   Check: `evidence/REPORT.md` lists the run and no unverified evidence.
   Log: none; read the report.
6. **Automatic step shows who records it.** Press < on the card after an automatic step finished.
   Check: the finished step says "recorded by CheckThat" next to Recorded: Pass.
   Log: `[ct] step self.secure pass auto evidence matched`.
7. **Hidden card still records.** Setup: on the Run button step, hide the card with `/ct` and type `/ct status`. Then type `/ct` to show the card.
   Check: the card opens on the next step.
   Log: `[ct] status requested`, then `[ct] step self.secure pass auto evidence matched` before the card is shown.
8. **Export window covers the Run button.** On the Export results step, click Run (or type `/ct export`).
   Check: the results window opens over the card and the Run button is hidden behind it. Clicking the window does not press Run. The window has a title bar and a scroll box, and its status line says to press Ctrl+A, then Ctrl+C, like the KeepThat, DontDoThat and ClosestVendor report windows. Typing in the box changes nothing.
   Log: none; on screen only.
9. **Run button leaves with its step.** Finish the run on the Export results step, then fight a training dummy until combat ends.
   Check: the results screen shows no Run button, before and after the fight.
   Log: none when the button stayed hidden; one `[ct] run button hidden: nothing to run on this screen` line for the screen if the game showed it and CheckThat hid it again.

10. **A fact is recorded during a run.** Setup, in this order: type `/ct debug on`. Type `/ct import`, paste the contents of `build/selftest.ct`, press Import, then select Start run. Do the first three steps as the card says. On the "Report a fact" step, click Run on the card.
   Check: chat says "Reported the test fact." and the card records the step as passed by itself and moves to "Export results".
   Log: `[facts] recorded CheckThat selftest`, and `[ct] step self.facts pass auto evidence matched`. A `/ct log` report holds `Facts: 1, last: [CheckThat] selftest=1`.
11. **No fact once the run has ended.** Setup: after check 10, click Run in the card header, choose End run and answer Yes. Then click the chat box, type `/ct fact` and press Enter.
   Check: chat says "No run is open, so the test fact was not recorded."
   Log: no second `recorded CheckThat selftest` line. A new `/ct log` report still holds `Facts: 1, last: [CheckThat] selftest=1`.

12. **A screenshot inside a step reaches the report.** Setup: a plan with a step that has `screenshot: true`, a run on the Windows PC with the game folder mounted on the Mac. Open that step, press Print Screen once, then press Pass. On the Mac, type `tools/ct.py collect --wow <game folder> --verbose`.
    Check: `collect` says "1 new screenshots". It does not say a screenshot matched no attempt. If it does, it names the gap in seconds: that gap is the time difference between the two computers.
    Log: `evidence/runs/<run id>/shots/` holds `<step id>__<file name>`, and `report` lists it under the step (see issue 95).
13. **The run names the version under test.** Setup: KeepThat is installed and enabled, and its plan is imported. Start a run for KeepThat, then type `/reload`.
    Check: the run starts and the card opens as usual.
    Log: the run in `CheckThatDB.global.runs` holds `formatRev = 3` and `targetVersion` equal to the `## Version:` line of `KeepThat.toc`.
14. **A step for another class, and a step checked at run start.** On a character that is not a Mage, import `build/checkthat-0.21.ct` and play it past "Checked when the run starts".
   Check: the card never shows "A step for a Mage" or "Checked when the run starts". With the back arrow, the Mage step says it does not apply, with the reason, and the other says CheckThat checked it when the run started.
   Log: `[ct] step ct2100.mage inapplicable: This step is for a Mage.` The report shows `attempt 1: pass at run start` for ct2100.start and "not for this character" for ct2100.mage.

## 5. Categories and unit-test checks

Import `build/selftest.ct` first (`/ct import`). It has 16 steps in five categories: Card and Run button, Log evidence, Facts, Unit checks and Lua errors.

1. **Pick categories.** On the start screen, clear the "Lua errors" box and press Start run.
   Check: the card shows five bar segments, the last one empty, and "untested · 0 of 14 passed". No Lua errors steps appear.
   Log: `Categories: overall blue` and `  errors: off (not picked), 0 of 0 done` in the `/ct log` report.
2. **Typed facts.** Type `/ct run self.typed`, then click Run on the card.
   Check: the card records Pass by itself and the Facts bar segment stays blue and fills halfway.
   Log: `[ct] step self.typed pass auto evidence matched`.
3. **Unit checks.** Type `/ct run units`. On each of the next three steps ("Compare numbers", "Check text and a list", "Check every report of a fact") click Run. On "Count exactly" click Run once, then wait 20 seconds. A second click makes its checks fail at once. Wait for the last steps.
   Check: the first three and the last three record Pass by themselves, "Count exactly" records Pass by itself when the 20 seconds are up, and the Unit checks segment turns green.
   Log: `[ct] step self.compare pass auto evidence matched` (the same for `self.text`, `self.which`, `self.state`, `self.api.version`, `self.api.report`, `self.entry`) and `[ct] step self.exact pass auto evidence matched` and `[ct] step self.noerror pass auto evidence matched`.
4. **Add the error category and record an error.** Type `/ct run errors`. Wait 10 seconds on "No Lua error", then click Run on "Record a Lua error".
   Check: a fifth segment is in use, "No Lua error" passes by itself after 10 seconds, and the card records the second step by itself. The game may show its error window. That is expected. Do it once with BugGrabber loaded and once with it disabled.
   Log: `[errors] recorded an error`, and `CheckThatDB.global.errors` ends with `CheckThat self-test error`. `[errors] handler current` without BugGrabber and `[errors] handler blocked` with it.
5. **Colors and words.** Press Fail on one step in the Card and Run button category.
   Check: its segment turns red, the caption reads "1 failed · 0 of 14 passed", and pointing at the segment says the category failed. The Categories window (`/ct tracker`) and the Home page list the same words.
   Log: `Categories: overall red` in the `/ct log` report.
6. **Rerun asks first.** Click the Categories control on the card. In the window, click the row of the red category and choose Rerun category. Press the No button, then choose it again and accept.
   Check: nothing changes after No. After accepting the steps with a result are open again and the segment turns blue.
   Log: `[ct] rerun card: <n> steps reopened`.
7. **Rerun failed steps.** Press Fail on a step in one category and on a step in another. Click a row in the Categories window and choose Rerun failed and unverified steps in all categories. Accept.
   Check: the question says "Rerun the 2 failed or unverified steps?". Both failed steps are open again, and every step that passed keeps its result.
   Log: `[ct] rerun failed: 2 steps reopened`.
8. **Another addon takes the error handler.** Disable BugGrabber and reload. Start the self-test with the Lua errors category and type `/ct run self.error` to open "Record a Lua error". Type `/run seterrorhandler(function() end)`. Wait two seconds, then type `/ct selftest error`.
   Check: the game shows its error window for the test error, and the card records "Record a Lua error" by itself. The card shows no amber warning.
   Log: `[errors] another addon took the error handler: set ours again`, `[errors] handler current`, and `CheckThatDB.global.errors` ends with `[?] CheckThat self-test error`.
9. **A stack for the first error of a step.** With BugGrabber disabled, open "Record a Lua error" and click Run. Play on for a minute.
   Check: the game does not slow down and shows no second error window.
   Log: `CheckThatDB.global.errorStacks` holds one line for the step, cut to 600 characters, and `/ct log` shows `Last error stack:`. The first line of the stack names the code that raised the error, not `Errors.lua`. Forever: no slowdown; the trim of our own frames is not yet confirmed in the game.
10. **Amber warning.** Disable BugGrabber and reload. Open "No Lua error" (`/ct run self.noerror`), then type `/run seterrorhandler(function() end); seterrorhandler = function() end` and wait two seconds. Reload afterwards.
    Check: the card shows the amber line "CheckThat cannot detect new Lua errors." above the countdown.
    Log: `[errors] another addon took the error handler: set ours again` and no `recorded an error` line.
11. **A failed step keeps its log lines and the check that failed.** Type `/ct run self.exact`. Click Run twice in a row.
    Check: the step records Fail (red) and the game stays responsive.
    Log: the failed attempt of `self.exact` in `CheckThatDB.global.runs` holds `excerpt` with the new fact lines (at most 20, each at most 200 characters), and `tools/ct.py report` prints them under the attempt. The outcome that failed also holds `rule`, `source`, `window`, `matched` and `hits` (each hit has `n` and `line`), and the report prints a `check` line and the lines that decided it, marked `>` in the excerpt. The run also holds `formatRev = 1` and `writerVersion` equal to the TOC version, and the finished attempt holds `formatRev`.

12. **Take a category out.** Start the self-test with every category. In the Categories window (`/ct tracker`), click a row that has no result and choose Remove from run. Then click a row of a category you passed a step in.
    Check: the first row turns grey and reads "not picked", and its steps no longer count. The second row has no Remove from run item.
    Log: `[ct] deselect <category>`.
13. **Many categories.** Run `build/checkthat-0.16-picker.ct` with `build/checkthat-picker-fixture.ct` (see the plan's preamble). Or import any plan with more than eight categories. On the card start screen, press Choose categories, clear one box on page 2, then close the window and press Start run.
    Check: the card says one category fewer is picked, the window shows 14 rows with the < and > buttons, and the run leaves out the cleared category.
    Log: `CheckThatDB` run `selected` has no entry for the cleared category.
14. **A key records a result.** Open Key Bindings, AddOns, CheckThat and set a key for Pass. Close the window, open a step on the card and press the key. Press it again after you hide the card with `/ct`.
    Check: the step passes and the card moves on. With the card hidden, a chat line says to open the checklist and no result is recorded.
    Log: `[ct] step <id> pass`.

15. **Open the steps of a category.** Press the plus button at the left of a category row in the Categories window (`/ct tracker`). Click one of the steps that opened.
    Check: the steps list under the row, each with its result in words and a mark (passed, failed, open, not picked). The button turns into a minus. The card shows the step you clicked, and no result changes. A step of a category that is not picked shows "not picked" and a click on it does nothing. The minus button closes the list.
    Log: `[ct] tracker expand <category>`, `[ct] show step <id>` and `[ct] tracker collapse <category>`.

16. **A run tells an addon when it ends.** Type `/run CheckThat.OnRun("CheckThat", function(e, i) print("run " .. e .. " " .. tostring(i.reason)) end)`. Start the self-test, then click End run on the card and accept.
    Check: chat shows "run start nil" when the run starts and "run end ended" when you end it.
    Log: `[runevents] called CheckThat start` and `[runevents] called CheckThat end ended`.
17. **A last check sees an error from an earlier step.** Play the self-test to "Record a Lua error" and click Run. When the card shows "The run kept the error", type `/reload`.
    Check: after the reload the card records the step as passed by itself.
    Log: `[ct] step self.runerror pass auto evidence matched`.

## 6. Plan skills (no game needed)

These checks run in a coding agent, not in the game. Run `make install-skill` first. `make test` covers what code decides (bundle, `collect`, example plans, fixture data). These checks cover the conversation.

1. **One question per turn.** Ask the plan skill for a plan for issue #48 and answer each question. Do not give the scope up front.
   Check: the agent asks one question in each turn, says why, and gives a recommended answer. It skips what the repository answers and says what it assumed.
   Log: none; read the transcript.
2. **Simple steps.** In the same run, ask for a check that needs two actions, then ask once for one step that covers a sequence.
   Check: the first check becomes two steps. The second becomes one step with the note "Compound step, drafted on request."
   Log: none; read the plan files.
3. **One plan per character.** Say that two characters take part.
   Check: the agent drafts two plan files named `<name>.<role>.yaml`. Each preamble names the other file. A reviewer line names the partner file and a step ID. Both plans validate and compile.
   Log: `ct.py validate` prints ok for each file.
4. **Read a run back.** Run `python3 tools/verify_fixture.py <folder>`, then ask the verify skill to verify the plans and runs in `<folder>`.
   Check: step fx.1 is contradicted, fx.2 is unverified, fx.3 is not contradicted and fx.4 has no evidence. The tally set reads held, with "total 12" in both notes.
   Log: none; read the report.
5. **Two eligible runs.** Run `python3 tools/verify_fixture.py <folder> --ambiguous` and verify again.
   Check: the agent lists the two bank runs and asks which to use. It does not choose.
   Log: none; read the transcript.
6. **Load the plugin.** Run `make build-plugin`, then start `claude --plugin-dir build/plugin` in an addon repository. Type `/checkthat:plan`, then `/checkthat:verify`.
   Check: both commands exist and start their skill. With no PyYAML in `python3`, the skill prints the command that creates an environment and stops.
   Log: none; read the transcript.
7. **Offer at apply.** Finish the tasks of an OpenSpec change that alters a setting. Run `/opsx:apply` on it.
   Check: the agent offers the plan skill once and waits. It starts nothing if you decline.
   Log: none; read the transcript.
8. **Foundation plan.** Ask the plan skill for a plan to run before each release of an addon.
   Check: the agent asks "foundation or feature?" first, then asks for the pillars before it drafts a step. Every step suits one character of any class in one place. Steps that need more are named in the preamble.
   Log: `ct.py validate` on the plan prints ok and no wording warning; the plan has `purpose: foundation`.

## 7. Client census

Turn debug on with `/ct debug on` before step 1.

1. **Start a census.** Stand out of combat and type `/ct census`.
   Check: chat says the census started and tells you to wait.
   Log: `[census] started <build>`.
2. **Let it finish.** Wait for the next chat line.
   Check: chat says the census is complete and tells you to type /reload. No Lua error window shows.
   Log: `[census] done <build> <n> globals <m> tables <k> widget types <a> addon`, with `<a>` above 0 (CheckThat's own globals count there).
3. **Save it.** Type `/reload`.
   Check: the game reloads with no Lua error window.
   Log: `CheckThatDB.global.census` holds this build and has no CheckThat global (for example `CheckThatDB`) in `globals`. `ct.py census` writes a manifest for it.
